import * as vscode from 'vscode'

export function activate({ subscriptions }: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('cclink')

    console.log(config.get('serverURL'))

    let disposable = vscode.commands.registerCommand('cclink.helloWorld', () => {
        vscode.window.showInformationMessage(config.get('serverURL') as string)
    })

    subscriptions.push(disposable)

    const button = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100)
    button.text = 'Hello World !'
    button.command = 'cclink.helloWorld'
    button.show()
    subscriptions.push(button)
}
