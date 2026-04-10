const { Server } = require('socket.io');

const setupSocketConnection = (server) => {
  const io = new Server(server, {
    cors: {
      origin: '*', // Adjust for production
      methods: ['GET', 'POST']
    }
  });

  io.on('connection', (socket) => {
    console.log(`New client connected: ${socket.id}`);

    // Join user specific room or meeting room
    socket.on('join_room', (room) => {
      socket.join(room);
      console.log(`Client ${socket.id} joined room ${room}`);
    });

    // Handle incoming messages
    socket.on('send_message', (data) => {
      // Broadcast to specific room or user
      io.to(data.room).emit('receive_message', data);
    });

    socket.on('disconnect', () => {
      console.log(`Client disconnected: ${socket.id}`);
    });
  });

  return io;
};

module.exports = setupSocketConnection;
