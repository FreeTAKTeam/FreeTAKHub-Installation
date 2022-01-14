node.warn(Object.keys(msg.payload).length);

for (let i = 0; i < Object.keys(msg.payload).length; i++) {

    node.warn(Object.keys(msg.payload)[i])

    if (Object.values(msg.payload)[i].source) {

        msg.payload = +Object.keys(msg.payload)[i]

        node.send(msg)
    }

}

return;
