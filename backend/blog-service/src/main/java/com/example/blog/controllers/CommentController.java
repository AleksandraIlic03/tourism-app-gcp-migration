package com.example.blog.controllers;

import com.example.blog.models.Blog;
import com.example.blog.models.Comment;
import com.example.blog.repositories.BlogRepository;
import com.example.blog.repositories.CommentRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/comments")
public class CommentController {

    private final CommentRepository commentRepository;
    private final BlogRepository blogRepository;
    private final RestTemplate restTemplate;

    @Value("${follower-service.url:http://localhost:8084}")
    private String followerServiceUrl;

    public CommentController(CommentRepository commentRepository, BlogRepository blogRepository, RestTemplate restTemplate) {
        this.commentRepository = commentRepository;
        this.blogRepository = blogRepository;
        this.restTemplate = restTemplate;
    }

    @PostMapping("/{blogId}")
    public ResponseEntity<?> create(@PathVariable String blogId,
                                          @RequestBody java.util.Map<String, String> body,
                                          @RequestHeader("Authorization") String authHeader) {
        Long authorId = extractUserIdFromToken(authHeader);
        String username = extractUsernameFromToken(authHeader);

        Optional<Blog> blogOpt = blogRepository.findById(blogId);
        if (blogOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Blog blog = blogOpt.get();

        
        if (!authorId.equals(blog.getAuthorId()) && !isFollowing(authorId, blog.getAuthorId())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "You must follow this user before commenting on their blog"));
        }

        Comment comment = new Comment();
        comment.setBlogId(blogId);
        comment.setAuthorId(authorId);
        comment.setAuthorUsername(username);
        comment.setText(body.get("text"));
        comment.setCreatedAt(LocalDateTime.now());
        comment.setUpdatedAt(LocalDateTime.now());

        Comment saved = commentRepository.save(comment);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    private boolean isFollowing(Long followerId, Long followedId) {
        try {
            String url = followerServiceUrl + "/is-following/" + followerId + "/" + followedId;
            ResponseEntity<Map> response = restTemplate.getForEntity(url, Map.class);
            Object following = response.getBody() != null ? response.getBody().get("following") : null;
            return Boolean.TRUE.equals(following);
        } catch (RestClientException e) {
            
            return false;
        }
    }

    @GetMapping("/{blogId}")
    public ResponseEntity<List<Comment>> getByBlog(@PathVariable String blogId) {
        return ResponseEntity.ok(commentRepository.findByBlogIdOrderByCreatedAtDesc(blogId));
    }

    private Long extractUserIdFromToken(String authHeader) {
        String token = authHeader.replace("Bearer ", "");
        String[] parts = token.split("\\.");
        String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
        String idStr = payload.split("\"id\":")[1].split("[,}]")[0];
        return Long.parseLong(idStr.trim());
    }

    private String extractUsernameFromToken(String authHeader) {
        String token = authHeader.replace("Bearer ", "");
        String[] parts = token.split("\\.");
        String payload = new String(java.util.Base64.getUrlDecoder().decode(parts[1]));
        return payload.split("\"username\":\"")[1].split("\"")[0];
    }

    @PutMapping("/{commentId}")
    public ResponseEntity<Comment> update(@PathVariable String commentId,
                                          @RequestBody java.util.Map<String, String> body,
                                          @RequestHeader("Authorization") String authHeader) {
        Long userId = extractUserIdFromToken(authHeader);

        return commentRepository.findById(commentId)
                .map(comment -> {
                    if (!comment.getAuthorId().equals(userId)) {
                        return ResponseEntity.status(HttpStatus.FORBIDDEN).<Comment>build();
                    }
                    comment.setText(body.get("text"));
                    comment.setUpdatedAt(LocalDateTime.now());
                    return ResponseEntity.ok(commentRepository.save(comment));
                })
                .orElse(ResponseEntity.notFound().build());
    }
}