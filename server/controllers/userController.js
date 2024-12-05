const User = require('../models/User');
const bcrypt = require('bcrypt');
const s3 = require('../config/aws');

exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: 'Something went wrong' });
  }
};

const uploadToS3 = async (base64Image, fileName) => {
  const buffer = Buffer.from(base64Image, 'base64');
  const params = {
    Bucket: 'connectro', // Replace with your S3 bucket name
    Key: fileName, // e.g., "profile_images/userId.png"
    Body: buffer,
    ContentType: 'image/png', // You may dynamically set the content type based on image type
    ACL: 'public-read', // You can adjust the access control
  };

  try {
    const uploadResult = await s3.upload(params).promise();
    console.log(uploadResult);
    return uploadResult.Location; // The URL of the uploaded image
  } catch (err) {
    throw new Error('Failed to upload image to S3');
  }
};

exports.updateProfile = async (req, res) => {
  const { username, email, imageUrl, currentPassword, newPassword } = req.body;

  try {
    let uploadedImageUrl = imageUrl;

    // Check if a new image is provided as base64 data
    if (imageUrl && imageUrl.startsWith('data:image/')) {
      const base64Image = imageUrl.split(',')[1];
      const fileName = `profile_images/${req.userId}.png`;
      uploadedImageUrl = await uploadToS3(base64Image, fileName);
    }

    // Handle password change only if both passwords are provided
    if (currentPassword && newPassword) {
      console.log('Inside password update block');

      const user = await User.findById(req.userId);
      console.log('Existing User:', user);

      const isMatch = await bcrypt.compare(currentPassword, user.password);
      console.log('Is current password correct?', isMatch);

      if (!isMatch) {
        return res.status(400).json({ message: 'Current password is incorrect' });
      }

      // Hash the new password
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      console.log('New Hashed Password:', hashedPassword);

      // Update user profile including the password
      const updatedUser = await User.findByIdAndUpdate(
        req.userId,
        { username, email, password: hashedPassword, imageUrl: uploadedImageUrl },
        { new: true }
      );
      console.log('Updated User:', updatedUser);

      return res.json(updatedUser);
    }

    // If no password change, update other fields without modifying the password
    const updatedUser = await User.findByIdAndUpdate(
      req.userId,
      { username, email, imageUrl: uploadedImageUrl },
      { new: true }
    );
    console.log('Updated User (No Password Change):', updatedUser);

    res.json(updatedUser);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Something went wrong' });
  }
};
