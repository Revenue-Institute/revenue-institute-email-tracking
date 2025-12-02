/**
 * YouTube Video Tracking Integration
 * Tracks YouTube video events and sends them to Outbound Intent Engine
 * 
 * Usage:
 * 1. Load YouTube IFrame API: <script src="https://www.youtube.com/iframe_api"></script>
 * 2. Include this script after the tracking pixel
 * 3. Call initYouTubeTracking() after page load
 */

(function() {
  'use strict';

  // Track which videos have been initialized
  const trackedVideos = new Map();

  /**
   * Initialize YouTube tracking for all YouTube iframes on the page
   */
  function initYouTubeTracking() {
    // Wait for tracker to be available
    if (!window.oieTracker) {
      console.warn('⚠️ OutboundIntentTracker not found. YouTube tracking will not work.');
      return;
    }

    // Find all YouTube iframes
    const youtubeIframes = findYouTubeIframes();
    
    if (youtubeIframes.length === 0) {
      console.log('🎥 No YouTube iframes found on page');
      return;
    }

    console.log(`🎥 Found ${youtubeIframes.length} YouTube iframe(s)`);

    // Wait for YouTube API to be ready
    if (typeof YT === 'undefined' || typeof YT.Player === 'undefined') {
      // Load YouTube IFrame API if not already loaded
      loadYouTubeAPI(() => {
        initializePlayers(youtubeIframes);
      });
    } else {
      // API already loaded
      if (YT.ready) {
        YT.ready(() => {
          initializePlayers(youtubeIframes);
        });
      } else {
        initializePlayers(youtubeIframes);
      }
    }
  }

  /**
   * Find all YouTube iframes on the page
   * Also checks for Embedly-wrapped videos and dynamically loaded iframes
   */
  function findYouTubeIframes() {
    const youtubeIframes = [];
    const checkedIframes = new Set();

    // Method 1: Check all existing iframes
    const iframes = document.querySelectorAll('iframe');
    iframes.forEach((iframe, index) => {
      if (checkedIframes.has(iframe)) return;
      checkedIframes.add(iframe);
      
      const src = iframe.src || '';
      const dataSrc = iframe.getAttribute('data-src') || '';
      const fullSrc = src || dataSrc;
      
      // Check if it's a YouTube iframe (direct or via Embedly)
      if (fullSrc.includes('youtube.com/embed/') || 
          fullSrc.includes('youtu.be/') ||
          fullSrc.includes('youtube-nocookie.com/embed/') ||
          fullSrc.includes('youtube.com/watch') ||
          // Check for Embedly YouTube embeds
          (iframe.closest && iframe.closest('[data-embed]') && fullSrc.includes('youtube'))) {
        
        // Extract video ID
        const videoId = extractVideoId(fullSrc);
        
        if (videoId) {
          youtubeIframes.push({
            element: iframe,
            videoId: videoId,
            index: index,
            id: iframe.id || `youtube-player-${index}`
          });
        }
      }
    });

    // Method 2: Check for Embedly containers that might contain YouTube videos
    const embedlyContainers = document.querySelectorAll('[data-embed], .embedly-card, [class*="embedly"]');
    embedlyContainers.forEach((container) => {
      const iframe = container.querySelector('iframe');
      if (iframe && !checkedIframes.has(iframe)) {
        checkedIframes.add(iframe);
        const src = iframe.src || iframe.getAttribute('data-src') || '';
        if (src.includes('youtube')) {
          const videoId = extractVideoId(src);
          if (videoId) {
            youtubeIframes.push({
              element: iframe,
              videoId: videoId,
              index: youtubeIframes.length,
              id: iframe.id || `youtube-player-${youtubeIframes.length}`
            });
          }
        }
      }
    });

    // Method 3: Check for YouTube video elements (YouTube creates a <video> element inside the iframe)
    // This won't work due to cross-origin, but we can check the parent structure
    const videoElements = document.querySelectorAll('video');
    videoElements.forEach((video) => {
      // Check if video is inside an iframe or has YouTube-related attributes
      const parent = video.closest('iframe') || video.parentElement;
      if (parent && parent.tagName === 'IFRAME') {
        const iframe = parent;
        if (!checkedIframes.has(iframe)) {
          checkedIframes.add(iframe);
          const src = iframe.src || '';
          if (src.includes('youtube')) {
            const videoId = extractVideoId(src);
            if (videoId) {
              youtubeIframes.push({
                element: iframe,
                videoId: videoId,
                index: youtubeIframes.length,
                id: iframe.id || `youtube-player-${youtubeIframes.length}`
              });
            }
          }
        }
      }
    });

    return youtubeIframes;
  }

  /**
   * Extract YouTube video ID from URL
   */
  function extractVideoId(url) {
    if (!url) return null;
    
    const patterns = [
      // Standard embed URLs
      /(?:youtube\.com\/embed\/|youtu\.be\/|youtube-nocookie\.com\/embed\/)([^?&\/]+)/,
      // Watch URLs
      /[?&]v=([^?&]+)/,
      // Short URLs
      /youtu\.be\/([^?&\/]+)/,
      // Embedly URLs might have different formats
      /youtube\.com\/watch\?.*v=([^&]+)/
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match && match[1]) {
        return match[1];
      }
    }

    return null;
  }

  /**
   * Load YouTube IFrame API
   */
  function loadYouTubeAPI(callback) {
    // Check if already loading
    if (window.onYouTubeIframeAPIReady) {
      const originalCallback = window.onYouTubeIframeAPIReady;
      window.onYouTubeIframeAPIReady = function() {
        originalCallback();
        if (callback) callback();
      };
      return;
    }

    // Set up callback
    window.onYouTubeIframeAPIReady = callback;

    // Load the API script
    const tag = document.createElement('script');
    tag.src = 'https://www.youtube.com/iframe_api';
    const firstScriptTag = document.getElementsByTagName('script')[0];
    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
  }

  /**
   * Initialize YouTube players
   */
  function initializePlayers(youtubeIframes) {
    youtubeIframes.forEach((iframeInfo) => {
      // Skip if already tracked
      if (trackedVideos.has(iframeInfo.videoId)) {
        return;
      }

      try {
        // Create a unique ID for the player if it doesn't have one
        if (!iframeInfo.element.id) {
          iframeInfo.element.id = iframeInfo.id;
        }

        // Initialize player
        const player = new YT.Player(iframeInfo.element.id, {
          events: {
            'onReady': (event) => {
              console.log('🎥 YouTube player ready:', iframeInfo.videoId);
              setupVideoTracking(event.target, iframeInfo.videoId);
            },
            'onStateChange': (event) => {
              handleStateChange(event, iframeInfo.videoId);
            },
            'onError': (event) => {
              console.error('🎥 YouTube player error:', event.data);
            }
          }
        });

        trackedVideos.set(iframeInfo.videoId, {
          player: player,
          tracked25: false,
          tracked50: false,
          tracked75: false,
          tracked100: false,
          trackedWatched: false,
          playStartTime: null
        });

      } catch (error) {
        console.error('🎥 Error initializing YouTube player:', error);
      }
    });
  }

  /**
   * Set up video tracking for a YouTube player
   */
  function setupVideoTracking(player, videoId) {
    const videoInfo = trackedVideos.get(videoId);
    if (!videoInfo) return;

    // Set play start time when tracking starts
    if (videoInfo.playStartTime === null) {
      videoInfo.playStartTime = Date.now();
    }

    // Set up progress tracking interval
    const progressInterval = setInterval(() => {
      try {
        if (player.getPlayerState() === YT.PlayerState.PLAYING) {
          const currentTime = player.getCurrentTime();
          const duration = player.getDuration();
          
          if (!duration || duration <= 0) return;

          const percent = (currentTime / duration) * 100;

          // Track "video_watched" event - fires when user has watched at least 10 seconds OR 25% of video
          if (!videoInfo.trackedWatched && videoInfo.playStartTime !== null) {
            const watchedTime = Date.now() - videoInfo.playStartTime;
            
            // Fire "video_watched" if: watched 10+ seconds OR reached 25% completion
            if (currentTime >= 10 || percent >= 25) {
              videoInfo.trackedWatched = true;
              console.log('🎥 YouTube video watched event triggered');
              trackVideoWatched(videoId, currentTime, percent, Math.round(watchedTime / 1000));
            }
          }

          // Track progress milestones
          if (percent >= 25 && !videoInfo.tracked25) {
            videoInfo.tracked25 = true;
            console.log('🎥 YouTube video progress: 25%');
            trackVideoProgress(videoId, 25, currentTime, duration);
          }
          if (percent >= 50 && !videoInfo.tracked50) {
            videoInfo.tracked50 = true;
            console.log('🎥 YouTube video progress: 50%');
            trackVideoProgress(videoId, 50, currentTime, duration);
          }
          if (percent >= 75 && !videoInfo.tracked75) {
            videoInfo.tracked75 = true;
            console.log('🎥 YouTube video progress: 75%');
            trackVideoProgress(videoId, 75, currentTime, duration);
          }
          if (percent >= 100 && !videoInfo.tracked100) {
            videoInfo.tracked100 = true;
            console.log('🎥 YouTube video progress: 100%');
            clearInterval(progressInterval);
            trackVideoComplete(videoId, duration);
          }
        }
      } catch (error) {
        // Player might be destroyed or unavailable
        clearInterval(progressInterval);
      }
    }, 1000); // Check every second

    // Store interval for cleanup
    videoInfo.progressInterval = progressInterval;
  }

  /**
   * Handle YouTube player state changes
   */
  function handleStateChange(event, videoId) {
    const player = event.target;
    const state = event.data;
    const videoInfo = trackedVideos.get(videoId);

    switch (state) {
      case YT.PlayerState.PLAYING:
        console.log('🎥 YouTube video play:', videoId);
        if (videoInfo) {
          videoInfo.playStartTime = Date.now();
        }
        trackVideoPlay(videoId);
        break;

      case YT.PlayerState.PAUSED:
        console.log('🎥 YouTube video pause:', videoId);
        const currentTime = player.getCurrentTime();
        trackVideoPause(videoId, currentTime);
        break;

      case YT.PlayerState.ENDED:
        console.log('🎥 YouTube video ended:', videoId);
        if (videoInfo && !videoInfo.tracked100) {
          videoInfo.tracked100 = true;
          const duration = player.getDuration();
          trackVideoComplete(videoId, duration);
        }
        break;
    }
  }

  /**
   * Track video play event
   */
  function trackVideoPlay(videoId) {
    if (window.oieTracker) {
      window.oieTracker.track('video_play', {
        src: `https://www.youtube.com/watch?v=${videoId}`,
        videoId: videoId,
        platform: 'youtube',
        videoType: 'youtube'
      });
    }
  }

  /**
   * Track video pause event
   */
  function trackVideoPause(videoId, currentTime) {
    if (window.oieTracker) {
      window.oieTracker.track('video_pause', {
        src: `https://www.youtube.com/watch?v=${videoId}`,
        videoId: videoId,
        platform: 'youtube',
        currentTime: currentTime
      });
    }
  }

  /**
   * Track video progress event
   */
  function trackVideoProgress(videoId, progress, currentTime, duration) {
    if (window.oieTracker) {
      window.oieTracker.track('video_progress', {
        src: `https://www.youtube.com/watch?v=${videoId}`,
        videoId: videoId,
        platform: 'youtube',
        progress: progress,
        currentTime: currentTime,
        duration: duration
      });
    }
  }

  /**
   * Track video complete event
   */
  function trackVideoComplete(videoId, duration) {
    if (window.oieTracker) {
      window.oieTracker.track('video_complete', {
        src: `https://www.youtube.com/watch?v=${videoId}`,
        videoId: videoId,
        platform: 'youtube',
        duration: duration
      });
    }
  }

  /**
   * Track video watched event (fires when user watches 10+ seconds OR 25% of video)
   */
  function trackVideoWatched(videoId, watchedSeconds, watchedPercent, watchTime) {
    if (window.oieTracker) {
      window.oieTracker.track('video_watched', {
        src: `https://www.youtube.com/watch?v=${videoId}`,
        videoId: videoId,
        platform: 'youtube',
        watchedSeconds: watchedSeconds,
        watchedPercent: Math.round(watchedPercent),
        watchTime: watchTime, // seconds since play started
        threshold: watchedSeconds >= 10 ? 'time' : 'percentage'
      });
    }
  }

  // Track YouTube play button clicks as fallback (before iframe loads)
  function setupPlayButtonTracking() {
    // Find YouTube play buttons (ytp-large-play-button)
    const playButtons = document.querySelectorAll('.ytp-large-play-button, [class*="ytp-play-button"], [class*="ytp-cued-thumbnail"]');
    playButtons.forEach((button) => {
      if (button._oiePlayButtonTracked) return;
      button._oiePlayButtonTracked = true;
      
      button.addEventListener('click', () => {
        // Try to find the video ID from nearby elements
        const container = button.closest('[class*="ytp"], [data-video-id], iframe, [class*="embedly"]');
        let videoId = null;
        
        // Check for data attributes
        if (container) {
          videoId = container.getAttribute('data-video-id') || 
                   container.getAttribute('data-youtube-id') ||
                   container.getAttribute('data-video');
        }
        
        // Try to extract from iframe src if available
        if (!videoId) {
          const iframe = container?.querySelector('iframe') || 
                        document.querySelector('iframe[src*="youtube"], iframe[data-src*="youtube"]');
          if (iframe) {
            const src = iframe.src || iframe.getAttribute('data-src') || '';
            videoId = extractVideoId(src);
          }
        }
        
        // Try to extract from page URL or meta tags
        if (!videoId) {
          const metaVideoId = document.querySelector('meta[property="og:video"]')?.content ||
                             document.querySelector('meta[name="twitter:player"]')?.content;
          if (metaVideoId) {
            videoId = extractVideoId(metaVideoId);
          }
        }
        
        // Try to extract from any YouTube URL on the page
        if (!videoId) {
          const youtubeLinks = document.querySelectorAll('a[href*="youtube.com"], a[href*="youtu.be"]');
          for (const link of youtubeLinks) {
            const href = link.getAttribute('href');
            if (href) {
              videoId = extractVideoId(href);
              if (videoId) break;
            }
          }
        }
        
        // Try to extract from YouTube thumbnail image URLs (i.ytimg.com/vi_webp/VIDEO_ID/...)
        if (!videoId) {
          const thumbnailImages = container?.querySelectorAll('img[src*="i.ytimg.com"], [style*="i.ytimg.com"]') || [];
          for (const img of thumbnailImages) {
            const src = img.src || img.getAttribute('style') || '';
            const match = src.match(/i\.ytimg\.com\/vi[^\/]+\/([^\/]+)\//);
            if (match && match[1]) {
              videoId = match[1];
              break;
            }
          }
        }
        
        // Also check background-image styles
        if (!videoId && container) {
          const style = window.getComputedStyle(container).backgroundImage;
          if (style) {
            const match = style.match(/i\.ytimg\.com\/vi[^\/]+\/([^\/]+)\//);
            if (match && match[1]) {
              videoId = match[1];
            }
          }
        }
        
        if (videoId && window.oieTracker) {
          console.log('🎥 YouTube play button clicked, tracking:', videoId);
          window.oieTracker.track('video_play', {
            src: `https://www.youtube.com/watch?v=${videoId}`,
            videoId: videoId,
            platform: 'youtube',
            triggeredBy: 'play_button_click'
          });
        } else {
          console.log('🎥 YouTube play button clicked but video ID not found');
        }
      }, { once: false }); // Allow multiple clicks
    });
  }

  // Auto-initialize when DOM is ready
  // Try multiple times since YouTube iframes load dynamically
  function tryInitialize() {
    // First, set up play button tracking (works even before iframe loads)
    setupPlayButtonTracking();
    
    // Then try to initialize YouTube API tracking
    initYouTubeTracking();
    
    // Try again after delays (for dynamically loaded iframes)
    setTimeout(() => {
      setupPlayButtonTracking(); // Re-check for new buttons
      const videos = findYouTubeIframes();
      if (videos.length > 0 && trackedVideos.size === 0) {
        console.log('🎥 Found YouTube iframes on retry, initializing...');
        initYouTubeTracking();
      }
    }, 2000);
    
    setTimeout(() => {
      setupPlayButtonTracking(); // Re-check again
      const videos = findYouTubeIframes();
      if (videos.length > 0 && trackedVideos.size === 0) {
        console.log('🎥 Found YouTube iframes on second retry, initializing...');
        initYouTubeTracking();
      }
    }, 5000);
    
    // Final retry after 10 seconds
    setTimeout(() => {
      setupPlayButtonTracking();
      initYouTubeTracking();
    }, 10000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      setTimeout(tryInitialize, 500);
    });
  } else {
    setTimeout(tryInitialize, 500);
  }

  // Also watch for dynamically added YouTube iframes
  if (typeof MutationObserver !== 'undefined') {
    const observer = new MutationObserver((mutations) => {
      let hasNewYouTubeIframe = false;
      
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1) {
            const element = node;
            // Check if the added node is an iframe
            if (element.tagName === 'IFRAME') {
              const src = element.src || element.getAttribute('data-src') || '';
              if (src.includes('youtube.com/embed/') || 
                  src.includes('youtu.be/') || 
                  src.includes('youtube-nocookie.com/embed/') ||
                  src.includes('youtube.com/watch')) {
                hasNewYouTubeIframe = true;
              }
            }
            
            // Check if the added node contains iframes
            const iframes = element.querySelectorAll?.('iframe') || [];
            iframes.forEach(iframe => {
              const src = iframe.src || iframe.getAttribute('data-src') || '';
              if (src.includes('youtube.com/embed/') || 
                  src.includes('youtu.be/') || 
                  src.includes('youtube-nocookie.com/embed/') ||
                  src.includes('youtube.com/watch')) {
                hasNewYouTubeIframe = true;
              }
            });
            
            // Check for Embedly containers
            if (element.hasAttribute && (
                element.hasAttribute('data-embed') ||
                element.className?.includes('embedly') ||
                element.classList?.contains('embedly-card')
            )) {
              const iframe = element.querySelector('iframe');
              if (iframe) {
                const src = iframe.src || iframe.getAttribute('data-src') || '';
                if (src.includes('youtube')) {
                  hasNewYouTubeIframe = true;
                }
              }
            }
          }
        });
      });

      // Check for new play buttons
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1) {
            const element = node;
            if (element.classList?.contains('ytp-large-play-button') || 
                element.querySelector?.('.ytp-large-play-button') ||
                element.classList?.contains('ytp-cued-thumbnail')) {
              setupPlayButtonTracking();
            }
          }
        });
      });

      if (hasNewYouTubeIframe) {
        console.log('🎥 New YouTube iframe detected via MutationObserver, re-initializing...');
        setupPlayButtonTracking(); // Also set up play button tracking for new elements
        setTimeout(() => {
          initYouTubeTracking();
        }, 1000); // Wait a bit for iframe to fully load
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true, // Watch for src attribute changes
      attributeFilter: ['src', 'data-src'] // Only watch src changes
    });
  }

  // Expose function globally for manual initialization
  window.initYouTubeTracking = initYouTubeTracking;

})();

