func greet(_ name: String) {
    log("Hola " + name)
}

func main() {
    let name = "Rafa"
    greet(name)
    if name == "Rafa" {
        setText(id: "title", text: "🔥 Bienvenido Rafa")
    } else {
        log("No es Rafa")
    }
}
