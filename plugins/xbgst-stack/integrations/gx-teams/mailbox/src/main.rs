use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::time::Duration;
use xbgst_mailbox::{append_jsonl, gc_scratch, parse_last_line, MailRecord, MailRoots};

#[derive(Parser)]
#[command(name = "xbgst-mailbox")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    Append {
        path: PathBuf,
        #[arg(long)]
        ts: String,
        #[arg(long)]
        id: String,
        #[arg(long)]
        from: String,
        #[arg(long)]
        to: String,
        #[arg(long = "type")]
        ty: String,
        #[arg(long)]
        text: String,
    },
    Last {
        path: PathBuf,
    },
    GcScratch {
        #[arg(long, default_value_t = 86400)]
        max_age_secs: u64,
        #[arg(long)]
        root: Option<PathBuf>,
    },
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    match cli.cmd {
        Cmd::Append {
            path,
            ts,
            id,
            from,
            to,
            ty,
            text,
        } => {
            let rec = MailRecord {
                ts,
                id,
                from,
                to,
                ty,
                text,
            };
            append_jsonl(&path, &rec)?;
        }
        Cmd::Last { path } => {
            let rec = parse_last_line(&path)?;
            println!("{}", serde_json::to_string(&rec)?);
        }
        Cmd::GcScratch { max_age_secs, root } => {
            let root = root.unwrap_or_else(|| MailRoots::from_env().scratch);
            let n = gc_scratch(&root, Duration::from_secs(max_age_secs))?;
            println!("{n}");
        }
    }
    Ok(())
}
