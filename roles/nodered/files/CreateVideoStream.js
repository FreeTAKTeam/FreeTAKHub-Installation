msg.addr = global.get('FTH_FTS_URL');

msg.port = global.get('FTH_FTS_API_Port');

msg.streamPort = global.get('FTH_FTS_STREAM_Port');

msg.streamAddress = global.get('FTH_FTS_VIDEO_URL');

let streamPath = msg.payload;

let alias = msg.payload;

let streamProtocol = "rtsp";

msg.payload = [];

msg.payload = {
    alias: alias,
    streamProtocol: streamProtocol,
    streamAddress: msg.streamAddress,
    streamPort: msg.streamPort,
    streamPath: streamPath,
};

return msg;
