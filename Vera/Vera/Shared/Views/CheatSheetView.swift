import SwiftUI
import MarkdownUI

struct CheatSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Markdown(Self.content)
                    .markdownTheme(.gitHub)
                    .padding()
            }
            .navigationTitle("Markdown Reference")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #else
            .toolbar {
                ToolbarItem {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }

    // swiftlint:disable:next line_length
    private static let content = """
    # Markdown Reference

    ## Emphasis

    | Syntax | Result |
    |--------|--------|
    | `**bold**` | **bold** |
    | `*italic*` | *italic* |
    | `***both***` | ***both*** |
    | `~~strike~~` | ~~strike~~ |
    | `` `code` `` | `code` |

    ## Headings

    ```
    # H1
    ## H2
    ### H3
    #### H4
    ```

    ## Lists

    ```
    - Bullet item
      - Nested item

    1. First
    2. Second

    - [ ] Open task
    - [x] Done task
    ```

    ## Links & Images

    ```
    [Link text](https://example.com)
    ![Alt text](image.png)
    [![Alt](img.png)](https://example.com)
    ```

    ## Code

    Inline: `` `code` ``

    Fenced block:
    ````
    ```swift
    let x = 42
    ```
    ````

    ## Blockquotes & Dividers

    ```
    > A blockquote
    > spanning lines

    ---
    ```

    ## Tables

    ```
    | Col 1 | Col 2 | Col 3 |
    |-------|:-----:|------:|
    | left  | center| right |
    ```

    ## Footnotes

    ```
    Text with a note.[^1]

    [^1]: The footnote text.
    ```
    """
}

#Preview {
    CheatSheetView()
        .frame(width: 480, height: 600)
}
