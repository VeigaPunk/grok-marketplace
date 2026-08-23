use fs2::FileExt;
use serde::{Deserialize, Serialize};
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MailRecord {
    pub ts: String,
    pub id: String,
    pub from: String,
    pub to: String,
    #[serde(rename = "type")]
    pub ty: String,
    pub text: String,
}

#[derive(Debug, Clone)]
pub struct MailRoots {
    pub persist: PathBuf,
    pub scratch: PathBuf,
}

impl MailRoots {
    pub fn from_env() -> Self {
        let persist = std::env::var("GX_TEAMS_STATE")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                dirs_home()
                    .unwrap_or_else(|| PathBuf::from("."))
                    .join(".gx-teams")
            });
        let scratch = std::env::var("XBGST_MAIL_ROOT")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/tmp/xbgst-mail"));
        Self { persist, scratch }
    }
}

fn dirs_home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

fn open_append_nofollow(path: &Path) -> io::Result<std::fs::File> {
    let mut opts = OpenOptions::new();
    opts.create(true).append(true).write(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        opts.custom_flags(libc::O_NOFOLLOW | libc::O_APPEND | libc::O_CLOEXEC);
    }
    opts.open(path)
}

pub fn append_jsonl(path: &Path, rec: &MailRecord) -> io::Result<()> {
    let mut f = open_append_nofollow(path)?;
    f.lock_exclusive()?;
    let line = serde_json::to_string(rec).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    f.write_all(line.as_bytes())?;
    f.write_all(b"\n")?;
    f.unlock()?;
    Ok(())
}

pub fn parse_last_line(path: &Path) -> io::Result<MailRecord> {
    let f = OpenOptions::new().read(true).open(path)?;
    let reader = BufReader::new(f);
    let mut last = String::new();
    for line in reader.lines() {
        let line = line?;
        if !line.is_empty() {
            last = line;
        }
    }
    if last.is_empty() {
        return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "empty jsonl"));
    }
    serde_json::from_str(&last).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}

fn is_fnm_protected(root: &Path) -> bool {
    let canon = root.canonicalize().unwrap_or_else(|_| root.to_path_buf());
    let s = canon.to_string_lossy();
    if s.contains("fnm_multishells") {
        return true;
    }
    let fnm_dir = std::env::var("FNM_DIR")
        .map(PathBuf::from)
        .ok()
        .or_else(|| dirs_home().map(|h| h.join(".local/share/fnm")));
    if let Some(dir) = fnm_dir {
        let dir = dir.canonicalize().unwrap_or(dir);
        if canon == dir || canon.starts_with(&dir) {
            return true;
        }
    }
    if let Ok(xdg) = std::env::var("XDG_RUNTIME_DIR") {
        let xdg = PathBuf::from(xdg);
        let xdg = xdg.canonicalize().unwrap_or(xdg);
        if canon == xdg || canon.starts_with(&xdg) {
            return true;
        }
    }
    false
}

fn is_persist_root(root: &Path) -> bool {
    if let Ok(s) = std::env::var("GX_TEAMS_STATE") {
        if root == Path::new(&s) {
            return true;
        }
    }
    if let Some(h) = dirs_home() {
        if root == h.join(".gx-teams") {
            return true;
        }
    }
    let persist = MailRoots::from_env().persist;
    root == persist.as_path()
}

pub fn gc_scratch(root: &Path, max_age: Duration) -> io::Result<usize> {
    if is_persist_root(root) {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "gc_scratch refuses persist/GX_TEAMS_STATE",
        ));
    }
    if is_fnm_protected(root) {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "gc_scratch refuses fnm_multishells/FNM_DIR",
        ));
    }
    let meta = match fs::symlink_metadata(root) {
        Ok(m) => m,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(0),
        Err(e) => return Err(e),
    };
    if meta.file_type().is_symlink() || !meta.is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "gc_scratch refuses symlink or non-dir root",
        ));
    }
    let now = SystemTime::now();
    let mut n = 0usize;
    for ent in fs::read_dir(root)? {
        let ent = ent?;
        let ft = ent.file_type()?;
        if !ft.is_file() {
            continue;
        }
        let path = ent.path();
        if path.parent() != Some(root) {
            continue;
        }
        let meta = fs::symlink_metadata(&path)?;
        if !meta.is_file() {
            continue;
        }
        let mtime = meta.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        if now.duration_since(mtime).unwrap_or(Duration::ZERO) > max_age {
            fs::remove_file(&path)?;
            n += 1;
        }
    }
    Ok(n)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use std::fs;

    #[test]
    fn roundtrip_one_record() {
        let dir = env::temp_dir().join(format!("xbgst-mbox-rt-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let path = dir.join("box.jsonl");
        let rec = MailRecord {
            ts: "2026-08-22T00:00:00Z".into(),
            id: "abc".into(),
            from: "lead".into(),
            to: "gx-labrat-ping".into(),
            ty: "dm".into(),
            text: "hi".into(),
        };
        append_jsonl(&path, &rec).unwrap();
        let got = parse_last_line(&path).unwrap();
        assert_eq!(got, rec);
        let bytes = fs::read(&path).unwrap();
        assert!(bytes.ends_with(b"\n"), "append_jsonl must end with newline");
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn last_wins_two_records() {
        let dir = env::temp_dir().join(format!("xbgst-mbox-lw-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let path = dir.join("box.jsonl");
        let rec1 = MailRecord {
            ts: "2026-08-22T00:00:00Z".into(),
            id: "one".into(),
            from: "lead".into(),
            to: "gx-labrat-ping".into(),
            ty: "dm".into(),
            text: "first".into(),
        };
        let rec2 = MailRecord {
            ts: "2026-08-22T00:00:01Z".into(),
            id: "two".into(),
            from: "lead".into(),
            to: "gx-labrat-ping".into(),
            ty: "dm".into(),
            text: "second".into(),
        };
        append_jsonl(&path, &rec1).unwrap();
        append_jsonl(&path, &rec2).unwrap();
        let got = parse_last_line(&path).unwrap();
        assert_eq!(got, rec2);
        let raw = fs::read_to_string(&path).unwrap();
        assert!(raw.ends_with('\n'));
        assert_eq!(raw.lines().count(), 2);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn scratch_not_under_xdg_runtime() {
        let roots = MailRoots::from_env();
        let scratch = roots.scratch.canonicalize().unwrap_or(roots.scratch.clone());
        let xdg = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/run/user/1000".into());
        let xdg_path = PathBuf::from(&xdg);
        assert!(
            !scratch.starts_with(&xdg_path),
            "scratch {:?} must not be under XDG_RUNTIME_DIR {:?}",
            scratch,
            xdg_path
        );
        assert!(
            scratch.starts_with("/tmp") || env::var("XBGST_MAIL_ROOT").is_ok(),
            "default scratch should be under /tmp"
        );
    }

    #[test]
    fn gc_scratch_deletes_aged() {
        let dir = env::temp_dir().join(format!("xbgst-mbox-gc-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let aged = dir.join("old.jsonl");
        fs::write(&aged, "{}\n").unwrap();
        let file = OpenOptions::new().write(true).open(&aged).unwrap();
        let old = filetime::FileTime::from_unix_time(1, 0);
        filetime::set_file_handle_times(&file, None, Some(old)).unwrap();
        drop(file);
        let n = gc_scratch(&dir, Duration::from_secs(60)).unwrap();
        assert!(n >= 1);
        assert!(!aged.exists());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn append_missing_parent_fails() {
        let path = env::temp_dir().join(format!(
            "xbgst-mbox-noparent-{}/box.jsonl",
            std::process::id()
        ));
        let rec = MailRecord {
            ts: "t".into(),
            id: "i".into(),
            from: "a".into(),
            to: "b".into(),
            ty: "dm".into(),
            text: "x".into(),
        };
        let err = append_jsonl(&path, &rec).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::NotFound);
    }

    #[test]
    fn append_does_not_follow_symlink() {
        let dir = env::temp_dir().join(format!("xbgst-mbox-nofollow-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let target = dir.join("target.jsonl");
        fs::write(&target, "").unwrap();
        let link = dir.join("link.jsonl");
        let _ = fs::remove_file(&link);
        std::os::unix::fs::symlink(&target, &link).unwrap();
        let rec = MailRecord {
            ts: "t".into(),
            id: "i".into(),
            from: "a".into(),
            to: "b".into(),
            ty: "dm".into(),
            text: "x".into(),
        };
        let err = append_jsonl(&link, &rec).unwrap_err();
        assert!(
            err.kind() == io::ErrorKind::Other
                || err.raw_os_error() == Some(libc::ELOOP)
                || err.kind() == io::ErrorKind::InvalidInput
                || err.to_string().contains("Too many"),
            "expected ELOOP, got {err:?}"
        );
        assert_eq!(fs::read_to_string(&target).unwrap(), "");
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn parse_last_line_skips_trailing_blanks() {
        let dir = env::temp_dir().join(format!("xbgst-mbox-blank-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let path = dir.join("box.jsonl");
        let rec = MailRecord {
            ts: "t".into(),
            id: "i".into(),
            from: "lead".into(),
            to: "n".into(),
            ty: "dm".into(),
            text: "hi".into(),
        };
        let line = serde_json::to_string(&rec).unwrap();
        fs::write(&path, format!("{line}\n\n")).unwrap();
        let got = parse_last_line(&path).unwrap();
        assert_eq!(got, rec);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn gc_scratch_refuses_persist() {
        let persist = MailRoots::from_env().persist;
        let err = gc_scratch(&persist, Duration::from_secs(1)).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::PermissionDenied);
    }

    #[test]
    fn gc_scratch_refuses_fnm_multishells_name() {
        let dir = env::temp_dir().join(format!("fnm_multishells-refuse-{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let err = gc_scratch(&dir, Duration::from_secs(1)).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::PermissionDenied);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn gc_scratch_refuses_fnm_dir_default() {
        let home = dirs_home().expect("HOME");
        let fnm = home.join(".local/share/fnm");
        if fnm.is_dir() {
            let err = gc_scratch(&fnm, Duration::from_secs(1)).unwrap_err();
            assert_eq!(err.kind(), io::ErrorKind::PermissionDenied);
        }
    }
}
