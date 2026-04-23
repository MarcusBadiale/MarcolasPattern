# Plano de Melhorias — MarcolasPattern

## Visão Geral

Este documento organiza todas as melhorias identificadas na lib em **8 frentes de trabalho**, ordenadas por prioridade (impacto × esforço). Cada frente inclui o problema, a solução proposta, e exemplos concretos de código.

---

## Frente 1 — Diagnósticos de Compilação

**Problema:** Quando uma propriedade é ignorada (tipo não inferido, `var` sem tipo nem initializer), o dev não recebe nenhum aviso. A propriedade simplesmente some do `Data` struct.

**Por que isso importa?** Imagina um dev novo no time que escreve `let timeout = 30` no ViewModel e tenta usar `data.timeout` na view. O Xcode dá um erro de "value of type 'Data' has no member 'timeout'" — mas não diz *por quê* a propriedade sumiu. O dev vai achar que a macro tá bugada. Agora multiplica isso por um time de 5–10 pessoas: cada um vai perder tempo debugando a mesma coisa. Com um warning claro na linha da propriedade dizendo "não consegui inferir o tipo, adicione `: Int`", o problema se resolve em 2 segundos em vez de 20 minutos. Em libs baseadas em macros, o feedback do compilador *é* a documentação — se a macro fica muda quando algo dá errado, a experiência de uso degrada rápido.

**Solução:** Usar `context.diagnose(...)` no `MCViewModelMacro.expansion(...)` para emitir warnings quando uma propriedade for pulada.

**Onde mexer:** `MCViewModelMacro.swift` e `PropertyClassification.swift`

**Passos:**

1. Alterar `PropertyClassifier.classify(...)` para retornar um `Result<ClassifiedProperty, PropertySkipReason>` em vez de `ClassifiedProperty?`:

```swift
enum PropertySkipReason {
    case noTypeAnnotationOrInferrable(name: String)
    case unsupportedPattern(name: String)
}

struct ClassificationResult {
    let properties: [ClassifiedProperty]
    let skipped: [(name: String, reason: PropertySkipReason, node: SyntaxProtocol)]
}
```

2. No `MCViewModelMacro.expansion(...)`, iterar sobre `skipped` e emitir diagnósticos:

```swift
for (name, reason, node) in classified.skipped {
    let diag = Diagnostic(
        node: Syntax(node),
        message: MacroDiagnostic.propertySkipped(name: name, reason: reason),
        severity: .warning
    )
    context.diagnose(diag)
}
```

3. Criar um `MacroDiagnostic` conformando a `DiagnosticMessage`:

```swift
struct MacroDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    static func propertySkipped(name: String, reason: PropertySkipReason) -> Self {
        let msg: String
        switch reason {
        case .noTypeAnnotationOrInferrable:
            msg = "'\(name)' was skipped: add an explicit type annotation or use a recognizable initializer (e.g. let x: MyType = ...). It will not appear in the Data struct."
        case .unsupportedPattern:
            msg = "'\(name)' uses an unsupported pattern and was skipped."
        }
        return MacroDiagnostic(
            message: msg,
            diagnosticID: MessageID(domain: "MarcolasPattern", id: "skippedProperty"),
            severity: .warning
        )
    }
}
```

4. Adicionar testes que validem que os warnings aparecem:

```swift
func testWarnsOnUninferrableProperty() throws {
    assertMacroExpansion(
        """
        @MCViewModel
        struct VM {
            let timeout = 30
        }
        """,
        expandedSource: /* ... */,
        diagnostics: [
            DiagnosticSpec(
                message: "'timeout' was skipped: add an explicit type annotation...",
                line: 3, column: 5,
                severity: .warning
            )
        ],
        macros: testMacros
    )
}
```

---

## Frente 2 — Inferência de Tipo Expandida

**Problema:** `inferType(from:)` só reconhece `Foo()`, `Foo.init()`, `Foo.shared`. Literais (`let x = 30`), arrays (`let items = [String]()`), e outros padrões são ignorados.

**Por que isso importa?** Constantes simples são extremamente comuns em ViewModels reais: `let maxRetries = 3`, `let debounceInterval = 0.3`, `let placeholder = "Buscar..."`. Hoje, nenhuma dessas aparece no `Data` struct a não ser que o dev escreva o tipo explícito. Isso obriga todos a adotar um estilo verboso (`let maxRetries: Int = 3`) que vai contra as convenções idiomáticas do Swift, onde inferência de tipo é o padrão. Uma lib que te obriga a escrever mais código do que sem ela perde o propósito. Além disso, combinada com a Frente 1, os casos que *ainda* não conseguimos inferir pelo menos avisam o dev em vez de sumir silenciosamente.

**Onde mexer:** `PropertyClassification.swift`, função `inferType(from:)`

**Passos:**

1. Adicionar suporte a literais comuns:

```swift
// Integer literal → Int
if initializer.is(IntegerLiteralExprSyntax.self) {
    return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Int")))
}
// Float literal → Double
if initializer.is(FloatLiteralExprSyntax.self) {
    return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Double")))
}
// String literal → String
if initializer.is(StringLiteralExprSyntax.self) {
    return TypeSyntax(IdentifierTypeSyntax(name: .identifier("String")))
}
// Boolean literal → Bool
if let boolLit = initializer.as(BooleanLiteralExprSyntax.self) {
    return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Bool")))
}
// Array literal → [Element] (only empty: [Type]())
// Já coberto pelo FunctionCallExpr com GenericArgumentClause
```

2. Adicionar suporte a `[Type]()` (array vazio tipado):

```swift
if let call = initializer.as(FunctionCallExprSyntax.self),
   let arrayType = call.calledExpression.as(ArrayExprSyntax.self) {
    // Reconstruct the array type from the expression
}
```

3. Para casos que ainda não conseguimos inferir, cair na Frente 1 (diagnóstico de warning).

4. Testes para cada novo padrão:

```swift
func testInfersIntLiteral() throws {
    assertMacroExpansion(
        """
        @MCViewModel
        struct VM {
            let timeout = 30
        }
        """,
        expandedSource: /* Data struct com `public let timeout: Int` */,
        macros: testMacros
    )
}
```

---

## Frente 3 — Propagação de Erros em Funções `throws`

**Problema:** Funções `async throws` geram closures que fazem `try` internamente mas o tipo da closure retorna `-> Void` e o erro é engolido.

**Por que isso importa?** Pensa num cenário real: uma função `func saveProfile() async throws` que faz uma chamada de rede. Se a request falha, o erro é engolido silenciosamente pela closure gerada — a view nunca fica sabendo que deu problema. O usuário aperta "Salvar", nada acontece, nenhum feedback. O dev então precisa contornar isso adicionando um `@State var error` manual e um do/catch dentro da própria função, anulando a vantagem da macro. Em projeto grande, isso vira um padrão repetitivo em todo ViewModel que faz I/O, e todo dev novo vai cair na armadilha de achar que `throws` está sendo propagado quando não está. Propagar o `throws` na closure é a correção mais importante de correção de contrato — o tipo da closure precisa refletir o que a função realmente faz.

**Onde mexer:** `MCViewModelMacro.swift`, funções `closureType(for:)` e `closureWrapper(for:)`

**Solução:** Duas estratégias, dependendo do que fizer mais sentido para o projeto:

### Opção A — Propagar o throws na closure (recomendado)

Gerar a closure como `@Sendable () async throws -> ReturnType` e deixar o call-site decidir o que fazer com o erro:

```swift
private func closureType(for func_: ClassifiedFunction) -> String {
    let paramsStr = func_.parameters
        .map { $0.type.trimmedDescription }
        .joined(separator: ", ")
    let returnStr = func_.returnType?.trimmedDescription ?? "Void"
    var modifiers = ""
    if func_.isAsync { modifiers += " async" }
    if func_.isThrows { modifiers += " throws" }
    return "@Sendable (\(paramsStr))\(modifiers) -> \(returnStr)"
}
// closureType já faz isso! O problema está em closureWrapper
// que faz `try` sem propagar. Corrigir:

private func closureWrapper(for func_: ClassifiedFunction) -> String {
    // ... (mesmo setup de params)

    // Se a função tem throws, a closure também deve ter throws
    // e o `try` é propagado naturalmente
    if func_.isAsync {
        if paramNames.isEmpty {
            return "{ [self] in \(call) }"
        }
        return "{ [self] \(params) in \(call) }"
    }
    // ... sync case similar
}
```

### Opção B — Error handler configurável

Adicionar um mecanismo de error handling no Provider:

```swift
@propertyWrapper
struct _VMProvider: DynamicProperty {
    @State var lastError: Error? = nil

    // Closures que fazem try catch internamente
    // e populam lastError
}
```

Isso exporia `data.lastError` automaticamente. Porém é mais invasivo.

**Recomendação:** Opção A. Manter a closure `throws` é mais idiomático em Swift e dá controle total ao dev.

---

## Frente 4 — Segurança do `MainActor.assumeIsolated`

**Problema:** `MainActor.assumeIsolated` faz crash em runtime se chamada fora da main thread. Funções sync no Provider usam isso.

**Por que isso importa?** No uso normal (view chamando a closure), funciona porque SwiftUI roda na MainActor. Mas `assumeIsolated` é uma *asserção* em runtime, não uma garantia do compilador — se alguém chamar a closure de uma `Task.detached`, de um callback de URLSession, ou de qualquer contexto fora da main thread, o app crasha sem uma mensagem útil. Em projeto grande, onde múltiplos devs tocam no mesmo código e nem todos entendem o modelo de concorrência do Swift 6, isso é uma bomba-relógio. Anotar o Provider com `@MainActor` move a garantia para compile-time: o compilador impede usos incorretos antes do app rodar, que é exatamente o tipo de segurança que uma lib de macros deveria oferecer.

**Onde mexer:** `MCViewModelMacro.swift`, `closureWrapper(for:)`

**Solução:** Substituir por `@MainActor` na closure:

```swift
// Antes (perigoso):
"{ [self] in MainActor.assumeIsolated { self.doSomething() } }"

// Depois (seguro):
"{ [self] in await MainActor.run { self.doSomething() } }"
```

Porém isso torna a closure `async`. Se quiser manter sync, a alternativa é anotar o Provider inteiro como `@MainActor`:

```swift
@propertyWrapper @MainActor
struct _VMProvider: DynamicProperty {
    // Tudo aqui já roda na MainActor
    // Closures sync não precisam de assumeIsolated
}
```

Essa é a abordagem mais limpa. Como `DynamicProperty` é usado pelo SwiftUI (que roda na MainActor), isso é semanticamente correto.

**Impacto nos testes:** Os testes de macro expansion precisam ser atualizados para incluir `@MainActor` no expected output.

---

## Frente 5 — Injeção de Dependências

**Problema:** O Provider não tem `init`. Propriedades como `let repository = TodoRepository()` são hardcoded, impossibilitando mocks e testes.

**Por que isso importa?** Essa é provavelmente a barreira número 1 para adoção em projeto profissional. Sem injeção de dependências: (1) não dá pra escrever testes unitários — como testar a lógica de `addTodo()` se o `TodoRepository` real faz chamada de rede? (2) Não dá pra usar ambientes diferentes — staging, produção, preview usam o mesmo repository concreto. (3) Não dá pra criar SwiftUI Previews com dados fake de forma limpa. Em qualquer time que segue práticas mínimas de qualidade (testes, code review, CI), isso é um deal-breaker. A solução de gerar um `init` com defaults mantém a ergonomia para o caso simples (o dev não precisa mudar nada), mas abre a porta para injetar mocks quando necessário.

**Onde mexer:** `MCViewModelMacro.swift` (geração do Provider)

**Solução:** Gerar um `init` no Provider que aceita as dependências `regular` como parâmetros:

```swift
@propertyWrapper
struct _TodoListViewModelProvider: DynamicProperty {
    let repository: TodoRepository

    init(repository: TodoRepository = TodoRepository()) {
        self.repository = repository
    }
    // ...
}
```

**Passos:**

1. No `generateProvider(...)`, identificar propriedades `regular` que têm initializer.
2. Gerar um `init` com parâmetros para cada uma, usando o initializer original como valor default.
3. Na `@MCView`, o `var data` continua sem argumentos (usa os defaults).
4. Para testes ou previews, o dev pode criar o Provider manualmente:

```swift
// Em Preview:
struct TodoListView_Previews: PreviewProvider {
    static var previews: some View {
        // Injetar mock
        TodoListView(data: .init(repository: MockTodoRepository()))
    }
}
```

5. Para isso funcionar, o `@MCView` macro precisa gerar um `init` alternativo na View que aceita o Provider.

---

## Frente 6 — Composição de ViewModels

**Problema:** O `Data` struct é flat. ViewModels grandes ficam com dezenas de propriedades num nível só. Não há como compor ViewModels menores.

**Por que isso importa?** Telas complexas de apps reais (perfil com edição + upload de foto + validação + histórico, ou um checkout com endereço + pagamento + cupom + resumo) facilmente chegam a 15–20 propriedades e 10+ funções. Um `Data` struct flat com tudo isso vira um "god object" disfarçado — difícil de ler, difícil de manter, e impossível de reusar partes em outras telas. Se a tela de perfil e a tela de configurações compartilham a mesma lógica de "editar nome/email", hoje você precisa duplicar. Com composição (`@MCChild var form: ProfileFormViewModel`), cada pedaço de lógica vive no seu ViewModel, pode ser testado isoladamente, e pode ser reusado em qualquer tela. É o que transforma a lib de "útil pra telas simples" em "arquitetura escalável para o app inteiro".

**Solução:** Usar comentários de grupo para organizar propriedades por responsabilidade dentro do ViewModel:

```swift
@MCViewModel
struct ProfileViewModel {
    // Grupo: form
    @State var name: String = ""
    @State var email: String = ""

    // Grupo: loading
    @State var isLoading: Bool = false
    @State var error: String? = nil

    func save() async { ... }
}
```

Isso já melhora bastante a legibilidade sem adicionar complexidade à macro. Se no futuro surgir necessidade de composição real entre ViewModels, revisitamos — mas por agora, manter ViewModels menores e focados (um por tela ou por seção de tela) combinado com boa organização via comentários é suficiente.

---

## Frente 7 — Suporte a `@Observable`

**Problema:** A lib ignora `@Observable`, que é o futuro do SwiftUI.

**Por que isso importa?** A Apple introduziu `@Observable` no iOS 17 como substituto do `ObservableObject`, e `@Bindable` como forma de criar bindings a partir de objetos `@Observable`. Projetos novos estão adotando esse padrão, e projetos existentes estão migrando gradualmente. Se a lib só reconhece `@State`/`@Query`/`@Environment`, ela se torna incompatível com qualquer ViewModel que recebe um objeto `@Observable` via `@Bindable`. Num cenário prático: um dev tem um `@Observable class UserSettings` e quer usar `@Bindable var settings: UserSettings` no ViewModel — hoje a macro não sabe o que fazer com isso e ignora a propriedade. Não é necessário reescrever a lib inteira ao redor de `@Observable` (os dois paradigmas coexistem), mas reconhecer `@Bindable` como property wrapper conhecido garante que a lib funciona em projetos modernos sem forçar o dev a escolher entre a lib e o ecossistema atual do SwiftUI.

**Onde mexer:** `PropertyClassification.swift` e `MCViewModelMacro.swift`

**Solução:** Adicionar reconhecimento de `@Observable` / `@Bindable` como property wrappers conhecidos:

```swift
// Em findPropertyWrapper:
let knownWrappers: Set<String> = [
    "Query", "State", "Environment",
    "Bindable",    // novo
    "Observable",  // classe-level, tratamento diferente
]
```

Para `@Bindable var item: Item`:
- No Data struct → `@Bindable public var item: Item` (pass-through)
- No Provider → copiar o `@Bindable` como está

Para quando o ViewModel inteiro é `@Observable`:
- Isso é um paradigma diferente. A recomendação é não tentar encaixar `@Observable` no mesmo pattern, mas sim documentar que `@MCViewModel` é para o pattern struct + `@State`/`@Query`, e `@Observable` é uma alternativa direta que não precisa da lib.

---

## Frente 8 — Melhorias de DX (Developer Experience)

**Por que isso importa?** Cada uma dessas melhorias parece pequena isoladamente, mas juntas fazem a diferença entre uma lib que "funciona" e uma que os devs *gostam* de usar. Testes abrangentes dão confiança para refatorar sem medo de quebrar cenários existentes — essencial quando as frentes 1–7 mexem pesado no code generation. Doc comments no código gerado significam que o dev vê ajuda contextual no autocomplete do Xcode em vez de tipos opacos. E `debugDescription` evita aquele momento frustrante de fazer `po data` no debugger e ver um struct sem representação legível. Em projeto grande com onboarding frequente de devs, esses detalhes reduzem a curva de aprendizado de forma significativa.

### 8a. Expandir a suíte de testes

Adicionar testes para:
- Propriedades com tipos genéricos (`@State var items: Set<Item> = []`)
- Funções com return type (`func getCount() -> Int`)
- Múltiplos `@Environment` no mesmo ViewModel
- ViewModels vazios (edge case)
- ViewModels com apenas computed properties

### 8b. Documentação inline

Adicionar doc comments no código gerado para que o autocomplete do Xcode mostre documentação útil:

```swift
/// Auto-generated data struct for `TodoListViewModel`.
/// Access via `data` property in your `@MCView`.
public struct TodoListViewModelData { ... }
```

### 8c. Template de debug

Gerar um `description` ou `debugDescription` no Data struct para facilitar debugging:

```swift
extension TodoListViewModelData: CustomDebugStringConvertible {
    var debugDescription: String {
        "TodoListViewModelData(todos: \(todos.count) items, isLoading: \(isLoading))"
    }
}
```

---

## Ordem de Execução Recomendada

| Prioridade | Frente | Esforço | Impacto |
|:---:|:---|:---:|:---:|
| 1 | Frente 1 — Diagnósticos | Baixo | Alto |
| 2 | Frente 3 — Propagação de erros | Baixo | Alto |
| 3 | Frente 4 — MainActor seguro | Baixo | Médio |
| 4 | Frente 2 — Inferência expandida | Médio | Médio |
| 5 | Frente 5 — Injeção de dependências | Médio | Alto |
| 6 | Frente 6 — Organização (comentários) | Baixo | Baixo |
| 7 | Frente 8 — DX (testes, docs) | Médio | Médio |
| 8 | Frente 7 — Suporte @Observable | Médio | Médio |

As frentes 1–4 podem ser feitas em paralelo e são as que mais impactam a confiabilidade da lib com menor esforço. A frente 5 (injeção) é a mais crítica para adoção em projetos reais. A frente 6 agora é só organização via comentários — esforço mínimo, pode ser feita a qualquer momento.
