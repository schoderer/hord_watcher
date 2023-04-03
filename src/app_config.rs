use config::{Environment, File};

#[derive(Debug, serde::Deserialize, Clone)]
pub struct AppConfig {
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(default)]
    pub namespaces: Option<Vec<String>>,
}

fn default_port() -> u16 {
    3000
}

pub fn load_config() -> Result<AppConfig, config::ConfigError> {
    let config = config::Config::builder()
        .add_source(File::with_name("config").required(false))
        .add_source(
            Environment::with_prefix("app")
                .list_separator(",")
                .try_parsing(true),
        )
        .build()?;
    config.try_deserialize()
}
