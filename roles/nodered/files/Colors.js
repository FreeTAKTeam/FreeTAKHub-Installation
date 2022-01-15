var colors = ["red ", "blue ", "green "];
for (let i = 0; i < colors.length; i++) {
    msg.payload = colors[i];
    node.send(msg);
}
return;
