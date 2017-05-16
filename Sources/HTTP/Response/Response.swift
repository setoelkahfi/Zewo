import Core
import Venice

public final class Response : Message {
    public typealias UpgradeConnection = (Request, DuplexStream) throws -> Void
    
    public var status: Status
    public var headers: Headers
    public var version: Version
    public var body: Body
    
    public var storage: Storage = [:]
    
    public var upgradeConnection: UpgradeConnection?
    
    public var cookieHeaders: Set<String> = []
    
    public init(
        status: Status,
        headers: Headers,
        version: Version,
        body: Body
    ) {
        self.status = status
        self.headers = headers
        self.version = version
        self.body = body
    }
}

extension Response {
    public convenience init(
        status: Status,
        headers: Headers = [:]
    ) {
        self.init(
            status: status,
            headers: headers,
            version: .oneDotOne,
            body: .empty
        )
        
        contentLength = 0
    }
    
    public convenience init(
        status: Status,
        headers: Headers = [:],
        body stream: ReadableStream
    ) {
        self.init(
            status: status,
            headers: headers,
            version: .oneDotOne,
            body: .readable(stream)
        )
    }
    
    public convenience init(
        status: Status,
        headers: Headers = [:],
        body write: @escaping Body.Write
    ) {
        self.init(
            status: status,
            headers: headers,
            version: .oneDotOne,
            body: .writable(write)
        )
    }

    public convenience init(
        status: Status,
        headers: Headers = [:],
        body buffer: BufferRepresentable,
        timeout: Duration
    ) {
        self.init(
            status: status,
            headers: headers,
            version: .oneDotOne,
            body: .writable { stream in
                try stream.write(buffer, deadline: timeout.fromNow())
            }
        )

        contentLength = buffer.bufferSize
    }
    
    public convenience init(
        status: Status,
        headers: Headers = [:],
        content: Content,
        contentType: ContentType,
        bufferSize: Int = 2048,
        timeout: Duration = 5.minutes
    ) {
        self.init(
            status: status,
            headers: headers,
            version: .oneDotOne,
            body: .writable { stream in
                try contentType.serializer.serialize(
                    content,
                    stream: stream,
                    bufferSize: bufferSize,
                    deadline: timeout.fromNow()
                )
            }
        )
        
        self.contentType = contentType.mediaType
        self.contentLength = nil
        self.transferEncoding = "chunked"
    }
    
    public convenience init(
        status: Status,
        headers: Headers = [:],
        content: ContentRepresentable,
        contentType: ContentType,
        bufferSize: Int = 2048,
        timeout: Duration = 5.minutes
    ) {
        self.init(
            status: status,
            headers: headers,
            content: content.content,
            contentType: contentType,
            timeout: timeout
        )
    }
}

extension Response {
    public var cookies: Set<AttributedCookie> {
        get {
            var cookies = Set<AttributedCookie>()

            for header in cookieHeaders {
                if let cookie = AttributedCookie(header) {
                    cookies.insert(cookie)
                }
            }
            
            return cookies
        }
        
        set(cookies) {
            var cookieHeaders = Set<String>()
            
            for cookie in cookies {
                cookieHeaders.insert(cookie.description)
            }
            
            self.cookieHeaders = cookieHeaders
        }
    }
}

extension Response : CustomStringConvertible {
    public var statusLineDescription: String {
        return
            "HTTP/" + version.description + " " +
            status.description + "\n"
    }
    
    public var description: String {
        return
            statusLineDescription +
            headers.description
    }
}
