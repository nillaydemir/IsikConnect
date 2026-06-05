const supabase = require('../config/supabase').getAdminClient();

// Fetch active forum posts
const fetchPosts = async (req, res) => {
  const { category } = req.query;
  try {
    let query = supabase
      .from('forum_posts')
      .select(`
        *,
        users:author_id(first_name, last_name, role, profile_image_url, is_deleted),
        forum_likes(user_id),
        forum_comments(id, is_deleted)
      `)
      .eq('is_deleted', false);

    if (category) {
      query = query.eq('category', category);
    }

    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;

    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch forum posts error:', error);
    res.status(500).json({ message: 'Failed to fetch forum posts.', error: error.message });
  }
};

// Fetch a single post with nested relations
const fetchPostDetails = async (req, res) => {
  const { postId } = req.params;
  try {
    const { data, error } = await supabase
      .from('forum_posts')
      .select(`
        *,
        users:author_id(first_name, last_name, role, profile_image_url, is_deleted),
        forum_likes(user_id),
        forum_comments(id, is_deleted)
      `)
      .eq('id', postId)
      .single();

    if (error || !data) {
      return res.status(404).json({ message: 'Post not found.' });
    }

    res.status(200).json(data);
  } catch (error) {
    console.error('Fetch post details error:', error);
    res.status(500).json({ message: 'Failed to fetch post details.', error: error.message });
  }
};

// Fetch active comments for a specific post
const fetchComments = async (req, res) => {
  const { postId } = req.params;
  try {
    const { data, error } = await supabase
      .from('forum_comments')
      .select(`
        *,
        users:author_id(first_name, last_name, role, profile_image_url, is_deleted)
      `)
      .eq('post_id', postId)
      .eq('is_deleted', false)
      .order('created_at', { ascending: true });

    if (error) throw error;
    res.status(200).json(data || []);
  } catch (error) {
    console.error('Fetch forum comments error:', error);
    res.status(500).json({ message: 'Failed to fetch forum comments.', error: error.message });
  }
};

// Create a new forum post
const createPost = async (req, res) => {
  const { category, title, content, image_url, tags, event_date, meeting_link, participant_limit } = req.body;
  const authorId = req.user.id;

  if (!category || !content) {
    return res.status(400).json({ message: 'Category and content are required.' });
  }

  try {
    const { data, error } = await supabase
      .from('forum_posts')
      .insert({
        author_id: authorId,
        category,
        title: title || '',
        content,
        image_url: image_url || null,
        tags: tags || [],
        event_date: event_date || null,
        meeting_link: meeting_link || null,
        participant_limit: participant_limit || null,
        is_deleted: false,
        is_solved: false
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    console.error('Create forum post error:', error);
    res.status(500).json({ message: 'Failed to create forum post.', error: error.message });
  }
};

// Create a new comment
const addComment = async (req, res) => {
  const { postId } = req.params;
  const { content } = req.body;
  const authorId = req.user.id;

  if (!content) {
    return res.status(400).json({ message: 'Content is required.' });
  }

  try {
    const { data, error } = await supabase
      .from('forum_comments')
      .insert({
        post_id: postId,
        author_id: authorId,
        content,
        is_deleted: false,
        is_accepted: false
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    console.error('Add comment error:', error);
    res.status(500).json({ message: 'Failed to add comment.', error: error.message });
  }
};

// Toggle like
const toggleLike = async (req, res) => {
  const { postId } = req.params;
  const { isCurrentlyLiked } = req.body;
  const userId = req.user.id;

  try {
    if (isCurrentlyLiked) {
      const { error } = await supabase
        .from('forum_likes')
        .delete()
        .match({ post_id: postId, user_id: userId });
      if (error) throw error;
    } else {
      const { error } = await supabase
        .from('forum_likes')
        .upsert({ post_id: postId, user_id: userId });
      if (error) throw error;
    }
    res.status(200).json({ message: 'Like toggled successfully.' });
  } catch (error) {
    console.error('Toggle like error:', error);
    res.status(500).json({ message: 'Failed to toggle like.', error: error.message });
  }
};

// Accept comment as solution (Q&A)
const acceptAnswer = async (req, res) => {
  const { postId } = req.params;
  const { commentId } = req.body;
  const userId = req.user.id;

  try {
    // 1. Mark the post as solved (Security: only author can do it)
    const { data: post, error: fetchError } = await supabase
      .from('forum_posts')
      .select('author_id')
      .eq('id', postId)
      .single();

    if (fetchError || !post) {
      return res.status(404).json({ message: 'Forum post not found.' });
    }

    if (post.author_id !== userId) {
      return res.status(403).json({ message: 'Forbidden: Only the author can accept an answer.' });
    }

    const { error: postError } = await supabase
      .from('forum_posts')
      .update({ is_solved: true, accepted_answer_id: commentId })
      .eq('id', postId);

    if (postError) throw postError;

    // 2. Mark the comment as accepted
    const { error: commentError } = await supabase
      .from('forum_comments')
      .update({ is_accepted: true })
      .eq('id', commentId);

    if (commentError) throw commentError;

    res.status(200).json({ message: 'Answer accepted successfully.' });
  } catch (error) {
    console.error('Accept answer error:', error);
    res.status(500).json({ message: 'Failed to accept answer.', error: error.message });
  }
};

// Soft-delete a post (author or admin only)
const deletePost = async (req, res) => {
  const { postId } = req.params;
  const userId = req.user.id;
  const isAdmin = req.user.role === 'admin';

  try {
    const { data: post, error: fetchError } = await supabase
      .from('forum_posts')
      .select('author_id')
      .eq('id', postId)
      .single();

    if (fetchError || !post) {
      return res.status(404).json({ message: 'Post not found.' });
    }

    if (post.author_id !== userId && !isAdmin) {
      return res.status(403).json({ message: 'Forbidden: You cannot delete this post.' });
    }

    const { error } = await supabase
      .from('forum_posts')
      .update({ is_deleted: true })
      .eq('id', postId);

    if (error) throw error;
    res.status(200).json({ message: 'Post deleted successfully.' });
  } catch (error) {
    console.error('Delete post error:', error);
    res.status(500).json({ message: 'Failed to delete post.', error: error.message });
  }
};

// Soft-delete a comment (author or admin only)
const deleteComment = async (req, res) => {
  const { commentId } = req.params;
  const userId = req.user.id;
  const isAdmin = req.user.role === 'admin';

  try {
    const { data: comment, error: fetchError } = await supabase
      .from('forum_comments')
      .select('author_id')
      .eq('id', commentId)
      .single();

    if (fetchError || !comment) {
      return res.status(404).json({ message: 'Comment not found.' });
    }

    if (comment.author_id !== userId && !isAdmin) {
      return res.status(403).json({ message: 'Forbidden: You cannot delete this comment.' });
    }

    const { error } = await supabase
      .from('forum_comments')
      .update({ is_deleted: true })
      .eq('id', commentId);

    if (error) throw error;
    res.status(200).json({ message: 'Comment deleted successfully.' });
  } catch (error) {
    console.error('Delete comment error:', error);
    res.status(500).json({ message: 'Failed to delete comment.', error: error.message });
  }
};

// Update an existing post (author only)
const updatePost = async (req, res) => {
  const { postId } = req.params;
  const { category, title, content, image_url, meeting_link, event_date } = req.body;
  const userId = req.user.id;

  try {
    const { data: post, error: fetchError } = await supabase
      .from('forum_posts')
      .select('author_id')
      .eq('id', postId)
      .single();

    if (fetchError || !post) {
      return res.status(404).json({ message: 'Post not found.' });
    }

    if (post.author_id !== userId) {
      return res.status(403).json({ message: 'Forbidden: Only the author can update this post.' });
    }

    const { error } = await supabase
      .from('forum_posts')
      .update({
        category,
        title: title || '',
        content,
        image_url: image_url || null,
        meeting_link: meeting_link || null,
        event_date: event_date || null
      })
      .eq('id', postId);

    if (error) throw error;
    res.status(200).json({ message: 'Post updated successfully.' });
  } catch (error) {
    console.error('Update post error:', error);
    res.status(500).json({ message: 'Failed to update post.', error: error.message });
  }
};

// Mark a post as read
const markPostAsRead = async (req, res) => {
  const { postId } = req.body;
  const userId = req.user.id;

  try {
    const { error } = await supabase
      .from('forum_read_posts')
      .upsert({ post_id: postId, user_id: userId });

    if (error) throw error;
    res.status(200).json({ message: 'Post marked as read.' });
  } catch (error) {
    console.error('Mark post read error:', error);
    res.status(500).json({ message: 'Failed to mark post as read.', error: error.message });
  }
};

// Fetch read post IDs for current user
const fetchReadPostIds = async (req, res) => {
  const userId = req.user.id;
  try {
    const { data, error } = await supabase
      .from('forum_read_posts')
      .select('post_id')
      .eq('user_id', userId);

    if (error) throw error;

    const ids = (data || []).map(r => r.post_id);
    res.status(200).json(ids);
  } catch (error) {
    console.error('Fetch read posts error:', error);
    res.status(500).json({ message: 'Failed to fetch read post IDs.', error: error.message });
  }
};

// Upload forum image to Supabase Storage
const uploadForumImage = async (req, res) => {
  const file = req.file;
  if (!file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }

  try {
    const BUCKET_NAME = 'forum-images';
    const fileName = `${Date.now()}_${file.originalname.replace(/\s+/g, '_')}`;

    const { data, error: uploadError } = await supabase.storage
      .from(BUCKET_NAME)
      .upload(fileName, file.buffer, {
        contentType: file.mimetype,
        upsert: true
      });

    if (uploadError) throw uploadError;

    // Get Public URL
    const { data: { publicUrl } } = supabase.storage
      .from(BUCKET_NAME)
      .getPublicUrl(fileName);

    res.status(200).json({ imageUrl: publicUrl });
  } catch (error) {
    console.error('Upload forum image error:', error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
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
};
