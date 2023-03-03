import org.yaml.snakeyaml.Yaml

fun convertYamlToPuml(input: String): String {
    val states = Yaml().load(input) as List<Map<String, Any>>

    val puml = StringBuilder("@startuml\n")
    puml.append("[*] --> ${states.first()["name"]}\n")

    for (state in states) {
        val name = state["name"]
        val transitions = state["transitions"] as Map<String, String>?

        transitions?.forEach { (event, nextState) ->
            puml.append("$name --> $nextState : $event\n")
        }
    }

    puml.append("${states.last()["name"]} --> [*]\n")
    puml.append("@enduml")

    return puml.toString()
}
