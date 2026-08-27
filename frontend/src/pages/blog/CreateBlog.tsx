import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ReactMarkdown from 'react-markdown';
import api from '../../api';
import './Blog.scss';

export default function CreateBlog() {
  const navigate = useNavigate();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [images, setImages] = useState<string[]>([]);
  const [preview, setPreview] = useState(false);
  const [error, setError] = useState('');
  const [uploading, setUploading] = useState(false);

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;
    setUploading(true);
    for (let i = 0; i < files.length; i++) {
      const formData = new FormData();
      formData.append('file', files[i]);
      try {
        const res = await api.post('/blogs/upload', formData);
        setImages((prev) => [...prev, res.data.url]);
      } catch {
        setError('Failed to upload image');
      }
    }
    setUploading(false);
  };

  const removeImage = (index: number) => {
    setImages((prev) => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    try {
      await api.post('/blogs', { title, description, images });
      navigate('/blogs');
    } catch {
      setError('Failed to create blog');
    }
  };

  return (
   <div className="blog-page" style={{ paddingTop: '40px' }}>
      <button className="back-btn" type="button" onClick={() => navigate('/blogs')}>← Back</button>
      <div className="blog-form-card">
        <div className="blog-form-header">
          <h2>Create Blog</h2>
          <p className="blog-form-subtitle">Share something with the people who follow you — they'll see it in their feed and can leave comments.</p>
        </div>
        {error && <p className="auth-error">{error}</p>}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Title</label>
            <input value={title} onChange={(e) => setTitle(e.target.value)} required />
          </div>
          <div className="form-group">
            <label>
              Description (Markdown supported)
              <button type="button" className="preview-toggle" onClick={() => setPreview(!preview)}>
                {preview ? 'Edit' : 'Preview'}
              </button>
            </label>
            {preview ? (
              <div className="markdown-preview">
                <ReactMarkdown>{description}</ReactMarkdown>
              </div>
            ) : (
              <textarea
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={10}
                placeholder="Write your blog using **markdown**..."
                required
              />
            )}
          </div>
          <div className="form-group">
            <label>Images</label>
            <div className="image-upload-box">
              <input type="file" accept="image/*" multiple onChange={handleImageUpload} />
              <p className="image-upload-hint">{uploading ? 'Uploading...' : 'Optional — JPG or PNG, multiple allowed.'}</p>
              {images.length > 0 && (
                <div className="image-previews">
                  {images.map((url, i) => (
                    <div key={i} className="image-preview">
                      <img src={url} alt={`upload-${i}`} />
                      <button type="button" onClick={() => removeImage(i)}>×</button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
          <button className="blog-submit-btn" type="submit">Publish Blog</button>
        </form>
      </div>
    </div>
  );
}