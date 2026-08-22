#!/usr/bin/env python3
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOOT = os.path.join(ROOT, "scripts", "the-bootstrapper")
HOME = os.path.realpath(os.path.expanduser("~"))


def run(*args):
    return subprocess.run(
        [sys.executable, BOOT, *args], capture_output=True, text=True, timeout=60
    )


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="bs-test-", dir=HOME)
        self.addCleanup(self._cleanup)

    def _cleanup(self):
        import shutil

        shutil.rmtree(self.tmp, ignore_errors=True)

    def roster(self, name="roster"):
        d = os.path.join(self.tmp, name)
        os.makedirs(d, exist_ok=True)
        return d

    def agent(self, d, fname, content):
        p = os.path.join(d, fname)
        mode = "wb" if isinstance(content, bytes) else "w"
        with open(p, mode) as f:
            f.write(content)
        return p


class TestGolden(Base):
    def test_default_run_21_ok(self):
        r = run()
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        self.assertEqual(d["schema_version"], 1)
        self.assertEqual(len(d["agents"]), 22)
        self.assertTrue(all(a["status"] == "ok" for a in d["agents"]))
        self.assertTrue(re.fullmatch(r"[0-9a-f]{64}", d["source_hash"]))

    def test_judge_delegation(self):
        d = json.loads(run().stdout)
        judge = [a for a in d["agents"] if a["name"] == "the-judge"]
        self.assertEqual(len(judge), 1)
        self.assertIsNotNone(judge[0]["delegation"])
        self.assertEqual(
            judge[0]["delegation"]["task_types"], ["orchestration", "arbitration"]
        )
        self.assertEqual(judge[0]["delegation"]["dispatch_surface"], "opencode")

    def test_unknown_name_delegation_null(self):
        d = self.roster()
        self.agent(
            d, "the-nobody.md", "---\ndescription: x\nmode: subagent\n---\nbody\n"
        )
        r = run("--roster", d)
        self.assertEqual(r.returncode, 0, r.stderr)
        (a,) = json.loads(r.stdout)["agents"]
        self.assertIsNone(a["delegation"])

    def test_claude_async_detection(self):
        d = json.loads(run().stdout)
        by = {a["name"]: a for a in d["agents"] if a["source"] == "claude"}
        self.assertEqual(len(by), 4)
        self.assertTrue(by["the-kimiraikkoner"]["delegation"]["async"])
        self.assertTrue(by["the-puppeteer"]["delegation"]["async"])
        self.assertIsNone(by["the-musketeer"]["delegation"]["async"])
        self.assertIsNone(by["the-almanacker"]["delegation"]["async"])
        for a in by.values():
            self.assertEqual(a["delegation"]["dispatch_surface"], "claude-code")
            self.assertTrue(a["symlink"])


class TestDeterminism(Base):
    def test_two_runs_byte_identical(self):
        a = run()
        b = run()
        self.assertEqual(a.returncode, 0)
        self.assertEqual(a.stdout, b.stdout)
        self.assertNotIn('"timestamp', a.stdout)


class TestModelRoutes(Base):
    EXPECTED = {
        "the-critic": {"provider": "chatgpt", "model_id": "gpt-5.6-sol"},
        "the-reviewer": {"provider": "chatgpt", "model_id": "gpt-5.6-sol"},
        "the-mutation-tester": {"provider": "chatgpt", "model_id": "gpt-5.6-sol"},
        "the-sentinel": {"provider": "chatgpt", "model_id": "gpt-5.6-sol"},
        "the-revenger": {"provider": "chatgpt", "model_id": "gpt-daybreak-blue-latest"},
        "the-labrat": {"provider": "grok", "model_id": "grok-4.6"},
        "the-netsshark": {"provider": "grok", "model_id": "grok-4.6"},
        "the-scout": {"provider": "token-plan", "model_id": "qwen3.8-max"},
        "the-distiller": {"provider": "token-plan", "model_id": "qwen3.8-max"},
    }
    HOST_NATIVE = {
        "orch", "the-judge", "the-planner", "the-executor", "the-connector",
        "the-simplifier", "the-scribe", "the-architect",
        "the-almanacker", "the-kimiraikkoner",
        "the-musketeer", "the-puppeteer",
    }

    def test_model_routes_match_op_map(self):
        d = json.loads(run().stdout)
        by = {a["name"]: a for a in d["agents"]}
        for name, route in self.EXPECTED.items():
            self.assertEqual(by[name]["delegation"]["model_route"], route, name)
        for name in self.HOST_NATIVE:
            self.assertIsNone(by[name]["delegation"]["model_route"], name)
        routes = [
            a["delegation"]["model_route"]
            for a in d["agents"]
            if a["delegation"] and a["delegation"].get("model_route")
        ]
        self.assertEqual(len(routes), 9)

    def test_delegations_carry_no_command_strings(self):
        d = json.loads(run().stdout)
        for a in d["agents"]:
            if a["delegation"] is None:
                continue
            blob = json.dumps(a["delegation"])
            self.assertNotIn("xask", blob)
            self.assertNotIn("sekhmet", blob)
            self.assertNotIn("$(", blob)


class TestLiveRoutes(Base):
    EXPECTED = TestModelRoutes.EXPECTED
    HOST_NATIVE = TestModelRoutes.HOST_NATIVE
    SECRETS = {
        "openai": {"access": "OPENAISECRETTOKEN", "refresh": "OPENAIREFRESH"},
        "xai": {"access": "XAISECRETTOKEN"},
        "alibaba-token-plan": {"access": "ALIBABASECRETTOKEN"},
    }

    def authfile(self, data):
        p = os.path.join(self.tmp, "auth.json")
        with open(p, "w") as f:
            json.dump(data, f)
        return p

    def run_live(self, auth_path):
        env = dict(os.environ)
        env["BOOTSTRAPPER_AUTH_FILE"] = auth_path
        return subprocess.run(
            [sys.executable, BOOT, "--live"],
            capture_output=True, text=True, timeout=60, env=env,
        )

    def routes(self, d):
        return {
            a["name"]: a
            for a in d["agents"]
            if a["delegation"] and a["name"] in self.EXPECTED
        }

    def test_live_chatgpt_only_falls_back(self):
        r = self.run_live(self.authfile({"openai": {"access": "OPENAISECRETTOKEN"}}))
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        self.assertEqual(d["providers"], {"openai": "chatgpt"})
        by = self.routes(d)
        self.assertEqual(len(by), 9)
        sol = {"provider": "chatgpt", "model_id": "gpt-5.6-sol"}
        for name, route in by.items():
            self.assertIsNotNone(route["delegation"]["model_route"], name)
        # primaries that hold (chatgpt first in chain)
        for name in ("the-critic", "the-reviewer", "the-mutation-tester", "the-sentinel"):
            mr = by[name]["delegation"]["model_route"]
            self.assertEqual({k: mr[k] for k in ("provider", "model_id")}, sol, name)
            self.assertFalse(mr["fallback_used"], name)
        # fallbacks: revenger primary is daybreak (chatgpt present but chain[0]
        # also chatgpt -> daybreak WINS; grok/token-plan lanes drop to sol)
        rev = by["the-revenger"]["delegation"]["model_route"]
        self.assertEqual(rev["provider"], "chatgpt")
        self.assertEqual(rev["model_id"], "gpt-daybreak-blue-latest")
        self.assertFalse(rev["fallback_used"])
        for name in ("the-labrat", "the-netsshark", "the-scout", "the-distiller"):
            mr = by[name]["delegation"]["model_route"]
            self.assertEqual({k: mr[k] for k in ("provider", "model_id")}, sol, name)
            self.assertTrue(mr["fallback_used"], name)

    def test_live_full_auth_primaries_hold(self):
        r = self.run_live(self.authfile(self.SECRETS))
        self.assertEqual(r.returncode, 0, r.stderr)
        d = json.loads(r.stdout)
        self.assertEqual(
            d["providers"],
            {"openai": "chatgpt", "xai": "grok", "alibaba-token-plan": "token-plan"},
        )
        by = self.routes(d)
        self.assertEqual(len(by), 9)
        for name, route in self.EXPECTED.items():
            mr = by[name]["delegation"]["model_route"]
            self.assertEqual(
                {k: mr[k] for k in ("provider", "model_id")}, route, name
            )
            self.assertFalse(mr["fallback_used"], name)
        self.assertEqual(
            by["the-revenger"]["delegation"]["route_chain"],
            ["chatgpt/gpt-daybreak-blue-latest", "chatgpt/gpt-5.6-sol", "grok/grok-4.6"],
        )
        self.assertEqual(
            by["the-scout"]["delegation"]["route_chain"],
            ["token-plan/qwen3.8-max", "chatgpt/gpt-5.6-sol"],
        )
        # host-native lanes stay null, carry no chain
        allby = {a["name"]: a for a in d["agents"]}
        for name in self.HOST_NATIVE:
            dlg = allby[name]["delegation"]
            self.assertIsNotNone(dlg, name)
            self.assertIsNone(dlg["model_route"], name)
            self.assertNotIn("route_chain", dlg, name)

    def test_live_missing_or_empty_auth_all_null(self):
        missing = os.path.join(self.tmp, "no-such-auth.json")
        for label, path in (
            ("missing", missing),
            ("empty", self.authfile({})),
            ("non-dict", self.authfile(["not", "a", "dict"])),
        ):
            with self.subTest(label=label):
                r = self.run_live(path)
                self.assertEqual(r.returncode, 0, r.stderr)
                d = json.loads(r.stdout)
                self.assertEqual(d["providers"], {})
                by = self.routes(d)
                self.assertEqual(len(by), 9)
                for name, a in by.items():
                    self.assertIsNone(a["delegation"]["model_route"], name)
                    self.assertIn("no-auth-provider", a["warnings"], name)

    def test_live_tokens_never_leak(self):
        r = self.run_live(self.authfile(self.SECRETS))
        self.assertEqual(r.returncode, 0, r.stderr)
        for secret in ("OPENAISECRETTOKEN", "OPENAIREFRESH", "XAISECRETTOKEN", "ALIBABASECRETTOKEN"):
            self.assertNotIn(secret, r.stdout)
            self.assertNotIn(secret, r.stderr)

    def test_no_flag_schema_zero_drift(self):
        d = json.loads(run().stdout)
        self.assertEqual(
            set(d.keys()),
            {"schema_version", "source_hash", "godspeed_directive_sha256",
             "rosters", "agents", "collisions", "parse_errors"},
        )
        for a in d["agents"]:
            if a["delegation"] is None:
                continue
            self.assertEqual(
                set(a["delegation"].keys()),
                {"task_types", "dispatch_surface", "async", "model_route"},
            )
            mr = a["delegation"]["model_route"]
            if mr is not None:
                self.assertEqual(set(mr.keys()), {"provider", "model_id"})

    def test_live_deterministic_with_fixture(self):
        p = self.authfile(self.SECRETS)
        a = self.run_live(p)
        b = self.run_live(p)
        self.assertEqual(a.returncode, 0)
        self.assertEqual(a.stdout, b.stdout)


class TestPathBoundary(Base):
    def test_sibling_opencodex_dir_classifies_custom(self):
        sib = os.path.join(HOME, ".config", "opencodex-fix", "agents")
        os.makedirs(sib, exist_ok=True)
        self.addCleanup(
            lambda: __import__("shutil").rmtree(
                os.path.join(HOME, ".config", "opencodex-fix"), ignore_errors=True
            )
        )
        self.agent(sib, "sib.md", "---\ndescription: x\nmode: subagent\n---\nbody\n")
        r = run("--roster", sib)
        self.assertEqual(r.returncode, 0, r.stderr)
        (a,) = json.loads(r.stdout)["agents"]
        self.assertEqual(a["source"], "custom")
        self.assertIsNone(a["delegation"])


class TestParser(Base):
    def test_empty_dir(self):
        d = self.roster()
        r = run("--roster", d)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout)["agents"], [])

    def test_missing_frontmatter(self):
        d = self.roster()
        self.agent(d, "bad-one.md", "# no frontmatter here\nbody\n")
        d2 = json.loads(run("--roster", d).stdout)
        (a,) = d2["agents"]
        self.assertEqual(a["status"], "parse_error")
        self.assertEqual(a["error"], "missing frontmatter")
        self.assertIsNone(a["description"])
        self.assertEqual(len(d2["parse_errors"]), 1)

    def test_unclosed_frontmatter(self):
        d = self.roster()
        self.agent(d, "unclosed.md", "---\ndescription: never closed\nmode: x\n")
        (a,) = json.loads(run("--roster", d).stdout)["agents"]
        self.assertEqual(a["status"], "parse_error")
        self.assertEqual(a["error"], "unclosed frontmatter")
        self.assertIsNone(a["description"])
        self.assertIsNone(a["mode"])
        self.assertIsNone(a["model"])

    def test_crlf_closes_fine(self):
        d = self.roster()
        self.agent(
            d,
            "crlf.md",
            b"---\r\ndescription: windows line endings\r\nmode: subagent\r\n---\r\nbody\r\n",
        )
        (a,) = json.loads(run("--roster", d).stdout)["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertEqual(a["description"], "windows line endings")
        self.assertEqual(a["mode"], "subagent")

    def test_non_utf8_survives(self):
        d = self.roster()
        self.agent(
            d,
            "latin.md",
            b"---\ndescription: caf\xe9 na\xffve\nmode: subagent\n---\nbody\n",
        )
        r = run("--roster", d)
        self.assertEqual(r.returncode, 0, r.stderr)
        (a,) = json.loads(r.stdout)["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertIn("non-utf8-bytes", a["warnings"])
        self.assertIsNotNone(a["description"])

    def test_clean_ascii_no_non_utf8_warning(self):
        d = self.roster()
        self.agent(d, "clean.md", "---\ndescription: plain ascii\nmode: subagent\n---\nbody\n")
        r = run("--roster", d)
        self.assertEqual(r.returncode, 0, r.stderr)
        (a,) = json.loads(r.stdout)["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertNotIn("non-utf8-bytes", a["warnings"])

    def test_empty_description_null(self):
        d = self.roster()
        self.agent(d, "empty.md", "---\ndescription:\nmode: subagent\n---\nbody\n")
        (a,) = json.loads(run("--roster", d).stdout)["agents"]
        self.assertIsNone(a["description"])

    def test_colon_in_value_and_quotes(self):
        d = self.roster()
        self.agent(
            d,
            "colon.md",
            '---\ndescription: "runs at 10:30 daily"\nmode: subagent\n---\nbody\n',
        )
        (a,) = json.loads(run("--roster", d).stdout)["agents"]
        self.assertEqual(a["description"], "runs at 10:30 daily")

    def test_pem_false_positive(self):
        d = self.roster()
        body = "---\ndescription: cert holder\nmode: subagent\n---\n"
        body += "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n"
        self.agent(d, "pem.md", body)
        (a,) = json.loads(run("--roster", d).stdout)["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertEqual(a["description"], "cert holder")

    def test_unknown_keys_to_extra_and_multiline(self):
        d = self.roster()
        self.agent(
            d,
            "extra.md",
            "---\ndescription: x\nmode: subagent\ncustom-key: custom-value\n"
            "long-key: first\n  second part\n---\nbody\n",
        )
        (a,) = json.loads(run("--roster", d).stdout)["agents"]
        self.assertEqual(a["extra"]["custom-key"], "custom-value")
        self.assertIn("first", a["extra"]["long-key"])
        self.assertIn("second part", a["extra"]["long-key"])
        self.assertIn("multi-line-value", a["warnings"])


class TestSecurity(Base):
    HOSTILE = (
        "---\ndescription: pipes | here `backticks` ``` fence \x07 bell --- dash\t"
        + "tab QUOTE\"BREAK{\"evil\":true} "
        + "A" * 600
        + "\nmode: subagent\n---\nbody\n"
    )

    def test_hostile_description_sanitized_and_capped(self):
        d = self.roster()
        self.agent(d, "hostile.md", self.HOSTILE)
        r = run("--roster", d)
        self.assertEqual(r.returncode, 0, r.stderr)
        (a,) = json.loads(r.stdout)["agents"]
        desc = a["description"]
        self.assertIsNotNone(desc)
        self.assertLessEqual(len(desc.encode("utf-8")), 512)
        self.assertNotIn("`", desc)
        self.assertNotIn("---", desc)
        self.assertNotIn("\x07", desc)
        self.assertNotIn("\t", desc)
        self.assertNotIn("\n", desc)
        for m in re.finditer(r"\|", desc):
            self.assertEqual(desc[m.start() - 1], "\\")

    def test_injection_roundtrips_inside_valid_json(self):
        d = self.roster()
        self.agent(d, "inject.md", self.HOSTILE)
        r = run("--roster", d)
        parsed = json.loads(r.stdout)  # must not raise: payload stays data
        desc = parsed["agents"][0]["description"]
        again = json.loads(json.dumps(parsed))
        self.assertEqual(again["agents"][0]["description"], desc)
        self.assertEqual(
            set(parsed.keys()),
            {"schema_version", "source_hash", "godspeed_directive_sha256", "rosters", "agents", "collisions", "parse_errors"},
        )
        self.assertEqual(len(parsed["agents"]), 1)
        self.assertIn('QUOTE"BREAK{"evil":true}', desc)  # inert substring, not structure
        self.assertEqual(parsed["collisions"], [])

    def test_roster_outside_home_refused(self):
        outside = tempfile.mkdtemp(prefix="bs-outside-")
        self.addCleanup(lambda: __import__("shutil").rmtree(outside, ignore_errors=True))
        self.agent(outside, "sneaky.md", "---\ndescription: x\n---\nbody\n")
        r = run("--roster", outside)
        self.assertEqual(r.returncode, 2)  # D6: all-refused run exits 2
        d = json.loads(r.stdout)
        self.assertEqual(d["agents"], [])
        self.assertEqual(d["rosters"][0]["status"], "error")
        self.assertIn("HOME", d["rosters"][0]["error"])
        r2 = run("--roster", outside, "--allow-anywhere")
        self.assertEqual(len(json.loads(r2.stdout)["agents"]), 1)

    def test_out_outside_home_refused(self):
        r = run("--out", "/tmp/opencode/refused-out.json")
        self.assertEqual(r.returncode, 1)
        self.assertFalse(os.path.exists("/tmp/opencode/refused-out.json"))
        r2 = run("--out", "/tmp/opencode/allowed-out.json", "--allow-anywhere")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertTrue(os.path.exists("/tmp/opencode/allowed-out.json"))

    def test_out_through_symlink_refused(self):
        target = os.path.join(self.tmp, "target.json")
        with open(target, "w") as f:
            f.write("ORIGINAL")
        link = os.path.join(self.tmp, "link.json")
        os.symlink(target, link)
        r = run("--out", link)
        self.assertEqual(r.returncode, 1)
        with open(target) as f:
            self.assertEqual(f.read(), "ORIGINAL")

    def test_atomic_write_replaces_inode(self):
        dest = os.path.join(self.tmp, "out.json")
        with open(dest, "w") as f:
            f.write("OLD")
        os.chmod(dest, 0o644)
        old_ino = os.stat(dest).st_ino
        r = run("--out", dest)
        self.assertEqual(r.returncode, 0, r.stderr)
        st = os.stat(dest)
        self.assertNotEqual(st.st_ino, old_ino)
        self.assertEqual(stat.S_IMODE(st.st_mode), 0o600)
        with open(dest) as f:
            d = json.load(f)
        self.assertEqual(len(d["agents"]), 22)


class TestShadows(Base):
    def test_shadows_later_roster(self):
        d1 = self.roster("r1")
        d2 = self.roster("r2")
        body = "---\ndescription: x\nmode: subagent\n---\nbody\n"
        self.agent(d1, "dup.md", body)
        self.agent(d2, "dup.md", body)
        r = run("--roster", d1, "--roster", d2)
        agents = json.loads(r.stdout)["agents"]
        self.assertEqual(len(agents), 2)
        shadowed = [a for a in agents if a["shadows"]]
        self.assertEqual(len(shadowed), 1)
        winner = [a for a in agents if not a["shadows"]][0]
        self.assertEqual(shadowed[0]["shadows"], winner["id"])
        self.assertIn(d1, winner["path"])


class TestSymlinkRegression(Base):
    """Round-1 attack PoCs: symlinks must never be followed into harm."""

    def test_out_through_symlink_refused_and_target_intact(self):
        target = os.path.join(self.tmp, "target.json")
        with open(target, "w") as f:
            f.write("ORIGINAL")
        link = os.path.join(self.tmp, "link.json")
        os.symlink(target, link)
        r = run("--out", link)
        self.assertEqual(r.returncode, 1)
        self.assertIn("invalid output", r.stderr)
        self.assertTrue(os.path.islink(link))
        with open(target) as f:
            self.assertEqual(f.read(), "ORIGINAL")

    def test_escape_symlink_skipped_without_flag_scanned_with(self):
        d = self.roster()
        victim = "/etc/ssl/certs/ca-certificates.crt"
        if not os.path.isfile(victim):
            self.skipTest("no system bundle to target")
        os.symlink(victim, os.path.join(d, "escapee.md"))
        self.agent(d, "normal.md", "---\ndescription: x\nmode: subagent\n---\nbody\n")
        r = run("--roster", d)
        self.assertEqual(r.returncode, 0, r.stderr)
        agents = {a["name"]: a for a in json.loads(r.stdout)["agents"]}
        esc = agents["escapee"]
        self.assertTrue(esc["symlink"])
        self.assertEqual(esc["status"], "skipped")
        self.assertIn("escapes $HOME", esc["error"])
        self.assertIsNone(esc["description"])
        self.assertIsNone(esc["delegation"])
        self.assertEqual(agents["normal"]["status"], "ok")
        r2 = run("--roster", d, "--allow-anywhere")
        agents2 = {a["name"]: a for a in json.loads(r2.stdout)["agents"]}
        self.assertEqual(agents2["escapee"]["status"], "parse_error")
        self.assertEqual(agents2["escapee"]["error"], "missing frontmatter")

    def test_planted_delegations_symlink_not_followed(self):
        victim = os.path.join(self.tmp, "delegations.md")
        with open(victim, "w") as f:
            f.write("ORIGINAL")
        link = os.path.join(self.tmp, "delegations.json")
        os.symlink(victim, link)
        r = run("--out", link)
        self.assertEqual(r.returncode, 1)
        with open(victim) as f:
            self.assertEqual(f.read(), "ORIGINAL")
        self.assertTrue(os.path.islink(link))
        self.assertEqual(os.readlink(link), victim)

    def test_default_claude_symlinks_into_home_still_scan(self):
        d = json.loads(run().stdout)
        claude = [a for a in d["agents"] if a["source"] == "claude"]
        self.assertEqual(len(claude), 4)
        for a in claude:
            self.assertTrue(a["symlink"])
            self.assertEqual(a["status"], "ok")
            self.assertTrue(a["realpath"].startswith(HOME + os.sep))


class TestHostileForeignRoster(Base):
    """Fixtures live under /tmp/opencode: foreign, outside-$HOME roster."""

    def setUp(self):
        super().setUp()
        self.fdir = tempfile.mkdtemp(prefix="bs-hostile-", dir="/tmp/opencode")
        self.addCleanup(
            lambda: __import__("shutil").rmtree(self.fdir, ignore_errors=True)
        )

    def scan(self):
        r = run("--roster", self.fdir, "--allow-anywhere")
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout)

    def test_colon_space_value_parsed_full(self):
        self.agent(self.fdir, "colon.md", "---\ndesc: a: b\nmode: subagent\n---\nbody\n")
        (a,) = self.scan()["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertEqual(a["extra"]["desc"], "a: b")

    def test_fm_name_never_grants_identity_or_judge_template(self):
        self.agent(
            self.fdir,
            "hostile.md",
            "---\nname: the-judge\ndescription: impostor\nmode: subagent\n---\nbody\n",
        )
        (a,) = self.scan()["agents"]
        self.assertEqual(a["id"], "custom/hostile")
        self.assertEqual(a["name"], "the-judge")
        self.assertIsNone(a["delegation"])
        od = os.path.join(HOME, ".config/opencode", "bs-hostile-od")
        self.addCleanup(lambda: __import__("shutil").rmtree(od, ignore_errors=True))
        os.makedirs(od, exist_ok=True)
        self.agent(
            od,
            "hostile.md",
            "---\nname: the-judge\ndescription: impostor\nmode: subagent\n---\nbody\n",
        )
        (b,) = json.loads(run("--roster", od).stdout)["agents"]
        self.assertEqual(b["source"], "opencode")
        self.assertEqual(b["id"], "opencode/hostile")
        self.assertIsNone(b["delegation"])
        j = json.loads(run().stdout)
        self.assertEqual(len([a for a in j["agents"] if a["name"] == "the-judge"]), 1)

    def test_multiline_continuation_warns(self):
        self.agent(
            self.fdir,
            "multi.md",
            "---\ndescription: first\n  second part\nmode: subagent\n---\nbody\n",
        )
        (a,) = self.scan()["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertIn("multi-line-value", a["warnings"])
        self.assertIn("first", a["description"])
        self.assertIn("second part", a["description"])

    def test_pem_line_inside_frontmatter_does_not_close_it(self):
        body = "---\ndescription: cert holder\n"
        body += "-----BEGIN CERTIFICATE-----\nmode: subagent\n---\nbody\n"
        self.agent(self.fdir, "pem.md", body)
        (a,) = self.scan()["agents"]
        self.assertEqual(a["status"], "ok")
        self.assertEqual(a["description"], "cert holder")
        self.assertEqual(a["mode"], "subagent")

    def test_hostile_600b_description_sanitized_capped(self):
        desc = (
            "pipes | here `backticks` ``` fence \x07 bell --- dash\ttab "
            + "B" * 600
        )
        self.agent(
            self.fdir,
            "hostile.md",
            "---\ndescription: " + desc + "\nmode: subagent\n---\nbody\n",
        )
        (a,) = self.scan()["agents"]
        d = a["description"]
        self.assertIsNotNone(d)
        self.assertLessEqual(len(d.encode("utf-8")), 512)
        self.assertNotIn("`", d)
        self.assertNotIn("---", d)
        self.assertNotIn("\x07", d)
        self.assertNotIn("\t", d)
        for m in re.finditer(r"\|", d):
            self.assertEqual(d[m.start() - 1], "\\")


class TestRunsDir(Base):
    def test_runs_dir_writes_identical_bytes(self):
        rd = os.path.join(self.tmp, "runs")
        os.makedirs(rd)
        r = run("--runs-dir", rd)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"agents"', r.stdout)  # stdout behavior unchanged
        h = json.loads(r.stdout)["source_hash"]
        dest = os.path.join(rd, h + ".json")
        self.assertTrue(os.path.isfile(dest))
        self.assertFalse(os.path.islink(dest))
        self.assertEqual(stat.S_IMODE(os.stat(dest).st_mode), 0o600)
        with open(dest) as f:
            self.assertEqual(f.read(), r.stdout)

    def test_runs_dir_outside_home_refused_without_flag(self):
        rd = tempfile.mkdtemp(prefix="bs-runs-", dir="/tmp/opencode")
        self.addCleanup(lambda: __import__("shutil").rmtree(rd, ignore_errors=True))
        r = run("--runs-dir", rd)
        self.assertEqual(r.returncode, 1)
        self.assertIn("invalid runs dir", r.stderr)
        self.assertEqual(os.listdir(rd), [])
        r2 = run("--runs-dir", rd, "--allow-anywhere")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertEqual(len(os.listdir(rd)), 1)


if __name__ == "__main__":
    unittest.main()
