import { workspace, window, StatusBarAlignment, commands, Position } from 'vscode'
import type { ExtensionContext } from 'vscode'
import * as path from 'path'

const FILE_HEADER = '-- CC Link ID: '

export function activate({ subscriptions }: ExtensionContext) {
    const config = workspace.getConfiguration('cclink')

    subscriptions.push(
        commands.registerCommand('cclink.uploadFile', async () => {
            if (!window.activeTextEditor) return
            if (!window.activeTextEditor.document.getText()) return

            let serverURL = config.get('serverURL') as string
            if (serverURL.endsWith('/')) serverURL = serverURL.slice(0, -1)

            if (!(await checkServer(serverURL))) {
                window.showErrorMessage('CC Link server is not available')
                return
            }

            const fileContent = window.activeTextEditor.document.getText()
            const lines = fileContent.split('\n')
            const headerLine = lines.find(line => line.startsWith(FILE_HEADER))

            const fileName = path.basename(window.activeTextEditor.document.fileName)

            let id: number | undefined = undefined
            if (headerLine) {
                id = parseInt(headerLine.replace(FILE_HEADER, ''))
            }

            fetch(`${serverURL}/file`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    id,
                    name: fileName,
                    content: fileContent
                })
            })
                .then(res => {
                    if (!res.ok) {
                        throw new Error('Error uploading file')
                    }
                    return res.json()
                })
                .then(res => res as { id: number; name: string })
                .then(res => {
                    if (!id) {
                        //add header
                        window.activeTextEditor
                            ?.edit(editBuilder => {
                                editBuilder.insert(new Position(0, 0), `${FILE_HEADER}${res.id}\n`)
                            })
                            .then(() => {
                                window.activeTextEditor?.document.save()
                            })
                    }
                })
                .catch(err => {
                    window.showErrorMessage(err.message)
                })
        })
    )

    subscriptions.push(
        commands.registerCommand('cclink.changeServer', () => {
            window
                .showInputBox({
                    title: 'Change CC Link server',
                    value: config.get('serverURL') as string,
                    prompt: 'Enter the URL of the CC Link server'
                })
                .then(url => {
                    if (!url) return
                    if (url.endsWith('/')) url = url.slice(0, -1)
                    config.update('serverURL', url, true)
                })
        })
    )

    const button = window.createStatusBarItem(StatusBarAlignment.Left, 0)
    button.text = 'Upload to CC Link'
    button.command = 'cclink.uploadFile'
    button.show()
    subscriptions.push(button)
}

async function checkServer(url: string) {
    return new Promise<boolean>(resolve => {
        try {
            fetch(url).then(res => {
                resolve(res.ok)
            })
        } catch (err) {
            resolve(false)
        }
    })
}
