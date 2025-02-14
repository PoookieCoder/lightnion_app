class NetworkSecurityPlugin : FlutterPlugin, MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getServerCertificate" -> {
        val host = call.argument<String>("host")!!
        val port = call.argument<Int>("port")!!
        
        val cert = fetchCertificate(host, port)
        result.success(cert)
      }
      else -> result.notImplemented()
    }
  }

  private fun fetchCertificate(host: String, port: Int): String {
    val factory = TrustManagerFactory.getInstance(...)
    val context = SSLContext.getInstance("TLS")
    context.init(null, factory.trustManagers, null)
    
    val socket = context.socketFactory.createSocket(host, port) as SSLSocket
    socket.startHandshake()
    
    return (socket.session.peerCertificates[0] as X509Certificate)
            .encoded.toHexString()
  }
}
