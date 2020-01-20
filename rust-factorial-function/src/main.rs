use serde_json::json;
use actix_web::error;
use cloudevent::{Event, Reader, Writer};
use faas_rust_macro::faas_function;
use factorial::Factorial;

#[faas_function]
pub async fn function(input: Event) -> Result<Event, actix_web::Error> {
    let json_payload: serde_json::Value = input
        .read_payload()
        .ok_or(error::ErrorBadRequest("Event is missing a payload"))??;
    let number = json_payload
        .as_object()
        .and_then(|o| o.get("value"))
        .and_then(|v| v.as_u64())
        .ok_or(error::ErrorBadRequest("Event payload does not contain a numeric value field"))?;
    let json = json!({
        "factorial": number.factorial(),
        "value": number
    });
    let mut output: Event = Event::new();
    output.event_type = "factorial.demo".to_string();
    output.write_payload("application/json", json)?;
    Ok(output)
}
