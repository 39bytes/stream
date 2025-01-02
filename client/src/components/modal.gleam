// import gleam/dict
// import lustre
// import lustre/attribute.{type Attribute, attribute}
// import lustre/effect.{type Effect}
// import lustre/element.{type Element, element}
//
// pub const name = "modal"
//
// pub fn register() -> Result(Nil, lustre.Error) {
//   let app = lustre.component(init, update, view, dict.new())
//   lustre.register(app, name)
// }
//
// pub fn modal(attributes: List(Attribute(msg))) {
//   element(name, attributes, [])
// }
//
// type Msg {
//   UserOpenedModal
//   UserClosedModal
// }
//
// type Model {
//   Model(open: Bool)
// }
//
// fn init(_) -> #(Model, Effect(Msg)) {
//   todo
// }
//
// fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
//   todo
// }
//
// fn view(model: Model) -> Element(Msg) {
//   todo
// }
