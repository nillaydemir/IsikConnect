const express = require('express');
const multer = require('multer');
const router = express.Router();

const {
  fetchPosts,
  fetchPostDetails,
  fetchComments,
  createPost,
  addComment,
  toggleLike,
  acceptAnswer,
  deletePost,
  deleteComment,
  updatePost,
  markPostAsRead,
  fetchReadPostIds,
  uploadForumImage
} = require('../controllers/forumController');

const { protect } = require('../middlewares/authMiddleware');

const upload = multer({ storage: multer.memoryStorage() });

router.get('/posts', protect, fetchPosts);
router.post('/posts', protect, createPost);
router.get('/posts/read-ids', protect, fetchReadPostIds);
router.post('/posts/read', protect, markPostAsRead);
router.get('/posts/:postId', protect, fetchPostDetails);
router.put('/posts/:postId', protect, updatePost);
router.delete('/posts/:postId', protect, deletePost);

router.get('/posts/:postId/comments', protect, fetchComments);
router.post('/posts/:postId/comments', protect, addComment);
router.delete('/comments/:commentId', protect, deleteComment);

router.post('/posts/:postId/like', protect, toggleLike);
router.post('/posts/:postId/accept-answer', protect, acceptAnswer);

router.post('/upload-image', protect, upload.single('image'), uploadForumImage);

module.exports = router;
