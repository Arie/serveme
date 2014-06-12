//JSFiddle
function pingServer(ip, callback) {

    if (!this.inUse) {
        this.status = 'unchecked';
        this.inUse = true;
        this.callback = callback;
        this.ip = ip;
        var _that = this;
        this.img = new Image();
        start = new Date();
        this.img.onload = function () {
            end = new Date();
            _that.inUse = false;
            ping = end - start;
            _that.callback(ping);

        };
        this.img.onerror = function (e) {
            if (_that.inUse) {
                end = new Date();
                _that.inUse = false;
                //Compensate for TCP handshake
                ping = Math.round((end - start) / 2.0);
                ping = ping + "ms";
                _that.callback(ping, e);
            }

        };
        this.img.src = "http://" + ip + "?cachebreaker="+new Date().getTime();
        this.timer = setTimeout(function () {
            if (_that.inUse) {
                _that.inUse = false;
                _that.callback('timeout');
            }
        }, 1000);
    }
}
