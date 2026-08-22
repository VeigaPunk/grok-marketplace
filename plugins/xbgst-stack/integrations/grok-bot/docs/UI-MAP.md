# grok-bot UI map (Linux 0.18.0)

Live Grok Bot chrome as seen on this host via CDP `127.0.0.1:9333`
(`agent-browser --cdp 9333 snapshot -i`). App: `/opt/Grok Bot/sand`, window
class `grok-bot`. **Not** the xbgst L1 judge. Fleet identity lives in each
card's Description as `FLEET_MARK: grok-bot <name> NOT the xbgst L1 judge`.

Refs (`eNN`) rotate every snapshot. Click by `@ref` from a **fresh** tree;
accessible-name clicks fail.

Evidence: `/tmp/grokbot-ui/{new,account,settings-page,local-exec,rulebeh,plugin-filter,more,billing,theme,combo,live,post-restart}.txt`
plus `/tmp/grokbot-ui/r0/{snap-account,snap-attach,snap-react,snap-filter,snap-yours,snap-plugins,snap-general,live-home}.txt`.
Plan walk: `~/.xbgst/plans/plan-grok-bot-fleet-r0.md` (Data Walk + UI map).

---

## Warning — window Close vs dialog Close

Two (often three) controls share the accessible name **Close**. They are not
the same button.

| Close | Where | Live tree | Effect |
|---|---|---|---|
| Window Close | title-bar chrome, sibling of Minimize / Restore | `button "Close" [ref=e8]` on the root (`/tmp/grokbot-ui/new.txt`, `live.txt`, `r0/live-home.txt`) | Quits the Electron window. Not a dialog dismiss. |
| Settings Close | Settings overlay | `button "Close" [ref=e9]` under `region "General"` / `region "Usage & Billing"` (`settings-page.txt`, `billing.txt`) | Dismisses Settings. Leaves the app running. |
| Plugins Close | Plugins overlay | `button "Close" [ref=e4]` next to `heading "Plugins"` (`r0/snap-yours.txt`, `r0/snap-plugins.txt`) | Dismisses Plugins. Leaves the app running. |

Do not click window Close to leave a dialog. Do not treat dialog Close as
quit. Restart path is `bin/xbgst-surface-restart.sh` (argv0-anchored
`pkill -TERM -f '^/opt/Grok Bot/sand( |$)'`), not the title-bar Close.

---

## Warning — New is a stub factory

`button "New"` is **not** “create the fleet”. It is the stub factory
(`SAND_DEFAULT_AGENT_NAME = "New Bot"`). Clicking it opens `main "New chat"`
with combobox **Search or create Bots**; first option **Create new Bot** is
selected (`/tmp/grokbot-ui/new.txt`, `combo.txt`). Confirming that option
mints another empty **New Bot** card.

Do not click **New**, **Create new Bot**, or **Add** (Marketplace) to build
the xbgst-stack fleet. Edit existing named cards. Delete empty `New Bot`
stubs (sidebar right-click → Delete; not in the a11y tree).

---

## Window chrome

Home tree: `/tmp/grokbot-ui/r0/live-home.txt`, `/tmp/grokbot-ui/live.txt`,
`create-bot.txt`.

| Control | Type | Options / notes |
|---|---|---|
| New | button | **Stub factory.** Opens New chat + Search or create Bots. Forbidden as a fleet-create action. |
| Search | button | Filters the agent list. Live tree shows the button only (no expanded textbox in these snaps). |
| Agent list | region | One button per card. See [Sidebar roster](#sidebar-roster). |
| Plugins | button | Opens Plugins dialog (Marketplace \| Yours). |
| Open account menu | button `expanded=false` | See [Account menu](#account-menu). |
| Minimize | button | Window chrome. |
| Restore | button | Window chrome. |
| Close | button | **Window** Close — see warning above. |
| View agent settings | button `expanded=false` | Header. Per-agent form. CDP click returned Done; pane did not appear in this walk. |
| Grok Bot's Computer | button `expanded=false` | Box desktop. Click this walk did not open a pane. Asar: Update (data-preserving) vs Reset (destructive). |
| Conversation transcript | log | Articles with hover actions. |
| Prompt | textbox | Composer. Submit = CTRL+Return (inject helper). Sometimes labeled `Message <name>`. |
| Attach file | button `expanded=false` | Menu: **Attach files**, **Teach a task** (`r0/snap-attach.txt`). |
| Start voice input | button | Mic. Becomes Send message when Prompt is non-empty (asar). |
| Add reaction | button | See [Reactions](#reactions). |
| Reply to Agent message / Reply to your message | button | Inline reply. |
| More message actions | button | **Start a thread**, **Copy** (`more.txt`, `r0/snap-more.txt`). |
| Open exchange with \<agent\> | button | Cross-bot thread. Live: `Open exchange with xbgst`. |
| Show more | button | Truncated user message (`live.txt`). |
| Open / Save \<file\> | buttons | Artifact chips. Live: `Open PLAN-xbgst-gdsd-fknpft.md`, `Save PLAN-xbgst-gdsd-fknpft.md`. |

### New chat (after New)

`/tmp/grokbot-ui/new.txt`, `combo.txt`.

| Control | Type | Options / notes |
|---|---|---|
| Search or create Bots | combobox | Recipients listbox. |
| Create new Bot | option | **Same stub factory** as New. Selected in the live snap. Do not confirm. |
| Recipients | listbox | Create new Bot + every named card (incl. existing New Bot stubs). |

---

## Account menu

`Open account menu`. Full live menu: `/tmp/grokbot-ui/r0/snap-account.txt`
(and `r0/acct2.txt`). A later `/tmp/grokbot-ui/account.txt` omitted the first
item (tree truncated).

| Item | Type | Notes |
|---|---|---|
| Weekly usage 3% | menuitem `expanded=false` | Submenu. Live value 3%. |
| Get Grok Bot for iOS | menuitem | |
| Settings | menuitem | Opens Settings dialog. |
| About | menuitem | |
| Help Center | menuitem | |
| Send Feedback | menuitem | |
| Log out | menuitem | |

---

## Settings dialog (live IA)

Live Linux 0.18.0 tabs are **General · Usage & Billing · Updates**. Asar
five-tab map (General / Plugins / Team Setup / Appearance / Updates) is
**not** this build. Appearance and Agent live **inside General**.

Navigation: `navigation "Settings sections"` (`settings-page.txt`). Overlay
**Close** is dialog Close (`ref=e9`), not window Close.

### General

`/tmp/grokbot-ui/settings-page.txt`, `theme.txt`, `local-exec.txt`,
`rulebeh.txt`, `timezone.txt`, `r0/snap-general.txt`.

| Control | Type | Options (live) | Live value |
|---|---|---|---|
| Close | button | — | dialog dismiss |
| Copy email address | button | — | |
| Sign Out | button | — | |
| Theme | combobox | **Follow System** / **Light** / **Dark** (`theme.txt`) | Follow System |
| Timezone | combobox | Auto-detect (America/Sao Paulo) + IANA list (not fully enumerated; first rows Africa/Abidjan…) (`timezone.txt`) | Auto-detect (America/Sao Paulo) |
| Execution on Local Computer | combobox | **Always allow** / **Ask every time** / **Never allow** (`local-exec.txt`). Asar enum `always\|ask\|never`. | Always allow |
| Auto-review | switch | on / off | checked=true |
| Auto-review rule draft | textbox | free text | empty → Add rule disabled |
| Rule behavior | combobox | **Allow automatically** / **Ask first** (`rulebeh.txt`) | Allow automatically |
| Add rule | button | — | disabled until draft non-empty |
| Use hardware security keys | switch | on / off | checked=false, **disabled** |

### Usage & Billing

`/tmp/grokbot-ui/billing.txt`. A11y tree this walk:

| Control | Type | Notes |
|---|---|---|
| Close | button | dialog dismiss |
| Usage & Billing | heading 2 | |
| Usage | heading 3 | Weekly/on-demand numbers are visual, not in this tree. Plan walk: weekly 3% (resets in 4 days); on-demand $0 (resets in 28 days). |

### Updates

Tab button **Updates** is live (`settings-page.txt` nav). Clicking it this
walk did not yield a region (`/tmp/grokbot-ui/updates.txt`: `✗ No active page`;
`r0/snap-updates.txt` stayed on home chrome). Asar (not CDP-proven here):

| Control | Type | Options |
|---|---|---|
| Update Grok Bot's Computer | button **Update** | two-click confirm; data-preserving |
| Reset Grok Bot's Computer | button **Reset** | destructive |
| Update Track | combobox | **Stable** / **Nightly** |
| Check for Updates | button | app, not the box |

---

## Per-agent settings

Header button **View agent settings**. Form **not CDP-visible** this walk
(click `@e11` → Done; screenshot unchanged). Asar `sand-agent-settings`:

| Control | Type | Notes |
|---|---|---|
| Edit Avatar | button | |
| Name | textbox `aria-label="Agent name"` | placeholder Bob |
| Title | textbox | “Describe what your agent does” |
| Description | multiline textbox | **Instructions.** This is where `FLEET_MARK` belongs. |
| Notifications | toggle | |
| Delete | confirm | Cancel / Delete / Deleting… Permanent. |
| Routines / Create Routine | | info pane (asar) |

Sidebar **right-click → Delete** is the stub-removal path. Not in the a11y
tree.

---

## Plugins dialog

`button "Plugins"`. Overlay **Close** is dialog Close (`r0/snap-yours.txt`
`ref=e4`).

| Control | Type | Options / notes |
|---|---|---|
| Close | button | dialog dismiss |
| Marketplace | tab | catalog. Each row: Open \<plugin\> + **Add**. **Do not Add.** |
| Yours | tab | Installed + Private |
| Filter plugins | button | See filter menu. |
| Search plugins | textbox | |

### Filter plugins

`/tmp/grokbot-ui/plugin-filter.txt`, `r0/snap-filter.txt`.

| Group | Menuitems |
|---|---|
| Type | **All types** · **Connectors** · **Skills** |
| Ownership | **All** · **Team** · **Public** |

### Marketplace categories (live)

`r0/snap-plugins.txt`: Featured, Agent Orchestration, Canvas, Customer
Support, Data Analytics, Design, Finance And Legal, Inbox And Collaboration,
Infrastructure, MCP, Payments, Productivity, Research, Sales, Scheduling.

Collapsed groups expose `Show N more`. Do not Add from MCP (or any category)
this plan.

### Yours → Installed (live)

`r0/snap-yours.txt`, `post-restart.txt`.

| Plugin | Buttons |
|---|---|
| GitHub | Open GitHub |
| Vercel | Open Vercel, **Authenticate** |
| 1Password | Open 1Password |
| X | Open X, **Authenticate** |
| Agent Compatibility | Open Agent Compatibility |

### Yours → Private (live, all unchecked)

| Skill | Enable switch |
|---|---|
| assign-model | checked=false |
| godspeed | checked=false |
| orch | checked=false |
| wwkd | checked=false |
| **xbgst** | checked=false — **leave off** (name collision with the judge skill) |

Opening a private skill edits name/description/instructions or deletes it
(asar). Do not enable Private `xbgst`.

---

## Reactions

`Add reaction` expanded: `/tmp/grokbot-ui/r0/snap-react.txt`.

| Button |
|---|
| React with 👍 |
| React with 👎 |
| React with ❤️ |
| React with 😂 |
| React with 🎉 |
| React with 😮 |
| More emoji |

---

## More message actions

`/tmp/grokbot-ui/more.txt`, `r0/snap-more.txt`.

| Menuitem |
|---|
| Start a thread |
| Copy |

---

## Attach file menu

`/tmp/grokbot-ui/r0/snap-attach.txt`.

| Menuitem |
|---|
| Attach files |
| Teach a task |

---

## Sidebar roster

Live order (`r0/live-home.txt`, `create-bot.txt`; 20 cards):

mutation-tester · **New Bot** · xbgst · the-planner · **New Bot** ·
the-janitor · **New Bot** · the-musketeer · the-revenger · scribe ·
simplifier · sentinel · critic · reviewer · labrat · scout · distiller ·
executor · connector · orch.

Named specialists (15) + `xbgst` forwarder + `orch` (keep unless E-orch) +
three empty **New Bot** stubs. Unread stub may render as
`button "New Bot, Unread activity"`.

Do not click **New** to add more.

---

## Operator don'ts (chrome)

| Do not | Why |
|---|---|
| Click **New** / **Create new Bot** | Stub factory, not fleet create. |
| Click window **Close** to leave Settings/Plugins | Quits the app. Use dialog Close. |
| Marketplace **Add** | No MCP add this plan. |
| Enable Private skill **xbgst** | Judge-named skill inside grok-bot. |
| Treat grok-bot **xbgst** card as L1 | Forwarder only. Description carries `FLEET_MARK`. |
