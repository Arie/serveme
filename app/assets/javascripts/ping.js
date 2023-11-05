function pingServer(ip, callback) {

    if (!this.inUse) {
        this.status = 'unchecked';
        this.inUse = true;
        this.callback = callback;
        this.ip = ip;
        var _that = this;
        socket = new WebSocket("wss://" + ip + "/ping");
        socket.addEventListener("open", function(event) {
            _that.start = new Date();
            socket.send("Ping!");
        });
        socket.addEventListener("message", function(event) {
            end = new Date();
            _that.inUse = false;
            ping = end - _that.start;
            _that.callback(ping + " ms");
        });
    }
}
