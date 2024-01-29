import { PrismaClient } from '@prisma/client'
import express from 'express'
import cors from 'cors'
import { createServer } from 'http'
import ws from 'ws'
import { z } from 'zod'
import path from 'path'
import fs from 'fs'

const PORT = parseInt(process.env.SERVER_PORT || '7541')
const URL = process.env.URL ?? 'http://localhost:' + PORT
console.log('URL :', URL)

const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

interface Computer {
    ws: ws.WebSocket
    fileIDs: number[]
}

const computers: Computer[] = []

const wsMessagesSchema = z.discriminatedUnion('type', [
    z.object({
        type: z.literal('register'),
        fileIDs: z.number().array()
    })
])

;(async () => {
    const prisma = new PrismaClient()
    const app = express()
    app.use(express.json())
    app.use(cors({ origin: '*' }))
    const httpServer = createServer(app)
    const wsServer = new ws.Server({ server: httpServer })

    httpServer.listen(PORT, () => console.log(`listening on port ${PORT}`))

    wsServer.on('connection', ws => {
        console.log('new websocket connection')

        ws.on('close', () => {
            console.log('websocket connection closed')
            computers.splice(
                computers.findIndex(c => c.ws === ws),
                1
            )
        })

        ws.on('message', async data => {
            const parseResult = wsMessagesSchema.safeParse(JSON.parse(data.toString()))
            if (!parseResult.success) {
                //received invalid message
                ws.send(JSON.stringify({ type: 'error', message: parseResult.error.message }))
                return
            }
            const { data: message } = parseResult

            switch (message.type) {
                case 'register':
                    const files = await prisma.file.findMany({
                        where: {
                            id: {
                                in: message.fileIDs
                            }
                        }
                    })
                    for (const fileID of message.fileIDs) {
                        if (!files.find(f => f.id === fileID)) {
                            ws.send(JSON.stringify({ type: 'error', message: `File with id ${fileID} does not exist` }))
                            return
                        }
                    }
                    computers.push({ ws, fileIDs: message.fileIDs })
                    await wait(500)
                    ws.send(JSON.stringify({ type: 'fileUpdate', files }))
                    break
            }
        })
    })

    app.post('/file', async (req, res) => {
        const schema = z.object({
            id: z.number().optional(),
            name: z.string(),
            content: z.string()
        })

        const parseResult = schema.safeParse(req.body)
        if (!parseResult.success) {
            res.status(400).send(parseResult.error.message)
            return
        }
        const { name, content, id } = parseResult.data

        if (id) {
            //id in request ---> update file
            let file = await prisma.file.findUnique({
                where: {
                    id
                }
            })
            // chech if file exists and if it does, update it
            if (file) {
                file = await prisma.file.update({
                    where: {
                        id
                    },
                    data: {
                        name,
                        content
                    }
                })

                // send update to all computers
                for (const computer of computers) {
                    if (computer.fileIDs.includes(id)) {
                        computer.ws.send(JSON.stringify({ type: 'fileUpdate', files: [file] }))
                    }
                }

                res.status(200).send({ id: file.id, name: file.name })
                return
            }
            // else create the file like if no id was provided
        }
        // no id in request ---> create file
        const file = await prisma.file.create({
            data: {
                name,
                content
            }
        })
        res.status(200).send({ id: file.id, name: file.name })
    })

    const CLIENTS_PATH = path.resolve(
        process.env.NODE_ENV === 'production' ? './clients/' : path.join(__dirname, '..', '..', 'clients/')
    )
    console.log('clients folder :', CLIENTS_PATH)
    app.get('/', (req, res) => {
        let file = fs.readFileSync(path.join(CLIENTS_PATH, 'setup.lua'), 'utf-8')
        file = file.replace('$$URL$$', URL)
        res.status(200).send(file)
    })
    app.get('/client', (req, res) => {
        let file = fs.readFileSync(path.join(CLIENTS_PATH, 'cc-link.lua'), 'utf-8')
        file = file.replace('$$URL$$', URL)
        res.status(200).send(file)
    })
})()
