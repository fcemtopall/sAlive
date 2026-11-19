import Foundation

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let service: HelperService

    init(service: HelperService) {
        self.service = service
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Only binaries signed by our team (app and CLI)
        // may talk to this root process.
        connection.setCodeSigningRequirement(SAlive.codeSigningRequirement)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

let service = HelperService()
let delegate = ListenerDelegate(service: service)
let listener = NSXPCListener(machServiceName: SAlive.helperMachService)
listener.delegate = delegate
listener.resume()
service.start()

RunLoop.main.run()
