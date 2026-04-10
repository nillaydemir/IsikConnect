require('dotenv').config();
const http = require('http');
const app = require('./app');
const { connectDB } = require('./src/config/db');

const PORT = process.env.PORT || 3000;

const server = http.createServer(app);

const startServer = async () => {
    try {
        await connectDB();

        server.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
};

startServer();
