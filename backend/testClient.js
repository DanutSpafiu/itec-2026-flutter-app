// Bare-bones Socket.IO connection tester without React Native
import { io } from "socket.io-client";

console.log("Attempting to connect to the custom server...");
const socket = io("http://localhost:3000");

socket.on("connect", () => {
  console.log("✅ SUCCESS! Connected! My Socket ID is:", socket.id);

  // 1. Simulate the phone recognizing Poster "1"
  console.log("📸 Mock: My phone scanned poster with ID 1...");
  socket.emit("phone_sees_poster", "1");
});

// Wait for the server to reply with old drawings (if any exist)
socket.on("load_drawing_history", (oldDrawings) => {
  console.log("📚 Received drawing history from Prisma:", oldDrawings);

  // 2. Simulate a finger drag on the screen (LIVE drawing) 
  // We send this immediately after the pop-up loaded
  console.log("☝️ Dragging a live colored line on the screen...");
  socket.emit("user_draws_line_live", {
      posterId: "1",
      coordinates: { x: 100, y: 200 }, // A mocked screen point
      color: "#FF6B6B",
      size: 16
  });
});

// Listen if anyone else draws live (Used by User 2 to see the lines)
socket.on("receive_live_line", (drawingData) => {
    console.log("LIVE: Saw someone draw coordinate point:", drawingData);
});

socket.on("disconnect", () => {
  console.log("❌ Server crashed or I got disconnected.");
});
