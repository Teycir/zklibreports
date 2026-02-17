use tracing::info;

fn main() {
    let subscriber = tracing_subscriber::fmt()
        .with_ansi(true)
        .with_target(false)
        .with_level(true)
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("set subscriber");

    let attacker = "\x1b]0;PWNED_TITLE\x07";
    info!("{}", attacker);
}
