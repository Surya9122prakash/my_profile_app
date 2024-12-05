const express = require('express');
const router = express.Router();
const { register, login } = require('../controllers/authController');
const authMiddleware = require('../middlewares/auth');

// Register route
router.post('/register', register);

// Login route
router.post('/login', login);

// Example of a protected route using the JWT middleware
router.get('/protected', authMiddleware, (req, res) => {
  res.status(200).json({ message: 'Protected route accessed', userId: req.userId });
});

module.exports = router;
