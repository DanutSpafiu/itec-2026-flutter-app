import { prisma } from '../config/prisma.js';
import bcrypt from 'bcrypt';

// Regex simplu pentru formatul standard (text@text.ext)
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// ---- REGISTER NEW USER ----
export const registerUser = async (req, res) => {
  try {
    const { email, password, name } = req.body;

    if(!email || !password || !name){
      return res.status(400).json({ error: "All fields are required!" });
    }

    if(!emailRegex.test(email)){
      return res.status(400).json({ error: "Please enter a valid email address!" });
    }

    if(password.length < 6){
      return res.status(400).json({ error: "Password must be at least 6 characters long!" });
    }

    if(name.length < 3){
      return res.status(400).json({ error: "Name must be at least 3 characters long!" });
    }

    // Check if user already exists
    const user = await prisma.user.findUnique({ where: { email: email } });
    if(user){
      return res.status(400).json({ error: "User already exists!" });
    }

    // Hash the password for security
    const hashedPassword = await bcrypt.hash(password, 10);

    // Save the new user in the database
    const newUser = await prisma.user.create({
      data: {
        email: email,
        password: hashedPassword,
        name: name
      }
    });

    res.status(201).json({ 
      message: "User created successfully",
      user: {
        id: newUser.id,
        name: newUser.name,
        email: newUser.email,
        teamId: newUser.teamId,
      }
    });
  } catch (error) {
    res.status(500).json({ error: "Registration error: " + error.message });
  }
};


// ---- AUTHENTICATE / LOGIN ----
export const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    if(!email || !password){
      return res.status(400).json({ error: "All fields are required!" });
    } 

    if(!emailRegex.test(email)){
      return res.status(400).json({ error: "Please enter a valid email address!" });
    } 

    const user = await prisma.user.findUnique({ where: { email: email } });
    
    // Fallback error message (to prevent email enumeration)
    if(!user){
      return res.status(400).json({ error: "Invalid email or password" });
    }

    // Compare hash
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if(!isPasswordValid){
      return res.status(400).json({ error: "Invalid email or password" });
    } 
    
    // Return user object without the password
    res.status(200).json({ 
      message: "Authentication successful (No JWT for now)",
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        teamId: user.teamId,
      }
    });
  } catch (error) {
    res.status(500).json({ error: "Authentication error: " + error.message });
  }
};
