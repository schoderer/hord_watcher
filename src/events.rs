use futures::stream::TryStreamExt;
use k8s_openapi::api::core::v1::Event;
use kube::ResourceExt;
use kube::{
    runtime::{watcher::watcher, watcher::Config, WatchStreamExt},
    Api,
};
use std::sync::Arc;

#[derive(Debug, Clone)]
pub enum WatchedNamespaces {
    All,
    Selected(Vec<String>),
}

pub async fn watch_kubernetes_events(watched_namespaces: WatchedNamespaces) -> anyhow::Result<()> {
    let kube_config = kube::Config::infer().await?;
    let client = kube::Client::try_from(kube_config)?;
    let event_api = Api::<Event>::all(client);
    let watched_namespaces = Arc::new(watched_namespaces);

    let namespace_watcher = watcher(event_api, Config::default())
        .applied_objects()
        .map_ok(move |event| (event, watched_namespaces.clone()))
        .try_for_each(|(p, namespaces)| async move {
            let resource_version = p.resource_version();
            let name = p.name_any();
            let namespace = p.metadata.namespace.unwrap_or_default();
            if let WatchedNamespaces::Selected(selected_namespaces) = namespaces.as_ref() {
                if !selected_namespaces
                    .iter()
                    .any(|ns| ns.eq_ignore_ascii_case(&namespace))
                {
                    return Ok(());
                }
            }
            tracing::info!(
                object_name = name,
                namespace = namespace,
                action = p.action.unwrap_or_default(),
                event_count = p.count.unwrap_or(1),
                resource_version = resource_version.unwrap_or_default(),
                message = p.message.unwrap_or_default(),
                reason = p.reason.unwrap_or_default(),
                event_type = p.type_.unwrap_or_default(),
                kubernetes = "Event"
            );
            Ok(())
        })
        .await;
    if let Err(watch_err) = namespace_watcher {
        tracing::error!("Watcher terminated due to error {watch_err}");
    }

    Ok(())
}
