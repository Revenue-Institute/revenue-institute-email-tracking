-- Session Aggregation Triggers
-- Automatically update session aggregates when events are inserted

-- Function to update session aggregates from events
CREATE OR REPLACE FUNCTION update_session_from_events()
RETURNS TRIGGER AS $$
BEGIN
  -- Update session with data from the new event
  UPDATE session
  SET
    -- Update first/last page
    first_page = COALESCE(first_page, NEW.url),
    last_page = NEW.url,
    
    -- Update location from first event
    country = COALESCE(country, NEW.country),
    city = COALESCE(city, NEW.city),
    region = COALESCE(region, NEW.region),
    
    -- Increment counters based on event type
    pageviews = pageviews + CASE WHEN NEW.type = 'page_view' THEN 1 ELSE 0 END,
    clicks = clicks + CASE WHEN NEW.type = 'click' THEN 1 ELSE 0 END,
    forms_started = forms_started + CASE WHEN NEW.type = 'form_start' THEN 1 ELSE 0 END,
    forms_submitted = forms_submitted + CASE WHEN NEW.type = 'form_submit' THEN 1 ELSE 0 END,
    videos_watched = videos_watched + CASE WHEN NEW.type IN ('video_watched', 'video_complete') THEN 1 ELSE 0 END,
    
    -- Update scroll depth if event has it
    max_scroll_depth = GREATEST(COALESCE(max_scroll_depth, 0), COALESCE((NEW.data->>'maxScrollDepth')::integer, 0)),
    
    -- Update active time if event has it
    active_time = COALESCE(active_time, 0) + COALESCE((NEW.data->>'activeTime')::integer, 0),
    
    -- Update end time
    end_time = NEW.created_at,
    
    -- Calculate duration
    duration = EXTRACT(EPOCH FROM (NEW.created_at - start_time))::integer,
    
    -- Update timestamp
    updated_at = NOW()
  WHERE id = NEW.session_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on event table
DROP TRIGGER IF EXISTS update_session_on_event_insert ON event;
CREATE TRIGGER update_session_on_event_insert
AFTER INSERT ON event
FOR EACH ROW
EXECUTE FUNCTION update_session_from_events();

-- Function to update web_visitor aggregates from events
CREATE OR REPLACE FUNCTION update_web_visitor_from_events()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if event belongs to a web_visitor (not a lead)
  IF NEW.web_visitor_id IS NOT NULL THEN
    UPDATE web_visitor
    SET
      -- Update page tracking
      first_page = COALESCE(first_page, NEW.url),
      last_page = NEW.url,
      
      -- Update location
      country = COALESCE(country, NEW.country),
      city = COALESCE(city, NEW.city),
      region = COALESCE(region, NEW.region),
      timezone = COALESCE(timezone, NEW.data->>'timezone'),
      
      -- Update UTM parameters from first event
      utm_source = COALESCE(utm_source, NEW.utm_source),
      utm_medium = COALESCE(utm_medium, NEW.utm_medium),
      utm_campaign = COALESCE(utm_campaign, NEW.utm_campaign),
      utm_term = COALESCE(utm_term, NEW.utm_term),
      utm_content = COALESCE(utm_content, NEW.utm_content),
      gclid = COALESCE(gclid, NEW.gclid),
      fbclid = COALESCE(fbclid, NEW.fbclid),
      
      -- Update referrer from first event
      first_referrer = COALESCE(first_referrer, NEW.referrer),
      
      -- Increment counters
      total_pageviews = total_pageviews + CASE WHEN NEW.type = 'page_view' THEN 1 ELSE 0 END,
      total_clicks = total_clicks + CASE WHEN NEW.type = 'click' THEN 1 ELSE 0 END,
      forms_started = forms_started + CASE WHEN NEW.type = 'form_start' THEN 1 ELSE 0 END,
      forms_submitted = forms_submitted + CASE WHEN NEW.type = 'form_submit' THEN 1 ELSE 0 END,
      videos_watched = videos_watched + CASE WHEN NEW.type IN ('video_watched', 'video_complete') THEN 1 ELSE 0 END,
      
      -- Update scroll depth
      max_scroll_depth = GREATEST(COALESCE(max_scroll_depth, 0), COALESCE((NEW.data->>'maxScrollDepth')::integer, 0)),
      
      -- Update active time
      total_active_time = COALESCE(total_active_time, 0) + COALESCE((NEW.data->>'activeTime')::integer, 0),
      
      -- Update last seen
      last_seen_at = NEW.created_at,
      last_page = NEW.url,
      
      -- Update timestamp
      updated_at = NOW()
    WHERE id = NEW.web_visitor_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on event table for web_visitor
DROP TRIGGER IF EXISTS update_web_visitor_on_event_insert ON event;
CREATE TRIGGER update_web_visitor_on_event_insert
AFTER INSERT ON event
FOR EACH ROW
EXECUTE FUNCTION update_web_visitor_from_events();

-- Function to update session count in web_visitor when session is created
CREATE OR REPLACE FUNCTION update_web_visitor_session_count()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if session belongs to a web_visitor (not a lead)
  IF NEW.web_visitor_id IS NOT NULL THEN
    UPDATE web_visitor
    SET
      total_sessions = total_sessions + 1,
      updated_at = NOW()
    WHERE id = NEW.web_visitor_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on session table for web_visitor
DROP TRIGGER IF EXISTS update_web_visitor_on_session_insert ON session;
CREATE TRIGGER update_web_visitor_on_session_insert
AFTER INSERT ON session
FOR EACH ROW
EXECUTE FUNCTION update_web_visitor_session_count();

COMMENT ON FUNCTION update_session_from_events IS 'Automatically updates session aggregates when events are inserted';
COMMENT ON FUNCTION update_web_visitor_from_events IS 'Automatically updates web_visitor aggregates when events are inserted';
COMMENT ON FUNCTION update_web_visitor_session_count IS 'Automatically increments session count in web_visitor when new session is created';
