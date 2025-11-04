# Deploy to Render.com

## Steps to Deploy

1. **Create Render Account**
   - Go to https://render.com
   - Sign up with GitHub/Google
   - No credit card required for free tier

2. **Create New Web Service**
   - Click "New +" → "Web Service"
   - Connect GitHub repository (capstone2)
   - Select repository

3. **Configure Service**
   - **Name**: `code-breaker-p2p-signaling`
   - **Root Directory**: `server`
   - **Runtime**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Instance Type**: Free (or Starter)

4. **Environment Variables**
   - Add in "Environment" tab:
     ```
     PORT=8080
     NODE_ENV=production
     ```

5. **Deploy**
   - Click "Create Web Service"
   - Render will build and deploy automatically
   - You'll get a URL like: `https://code-breaker-p2p-signaling.onrender.com`

6. **Update Godot with Server URL**
   - In `code_breaker_arena.gd`:
     ```gdscript
     const SIGNALING_SERVER = "wss://code-breaker-p2p-signaling.onrender.com/ws/game"
     ```

## Local Testing

```bash
cd server
npm install
npm start
```

Then in Godot use:
```gdscript
const SIGNALING_SERVER = "ws://localhost:8080/ws/game"
```

## Monitoring

- Health: `https://code-breaker-p2p-signaling.onrender.com/health`
- Stats: `https://code-breaker-p2p-signaling.onrender.com/stats`

## Cold Start Issues

Render's free tier spins down after 15 minutes of inactivity. To prevent:
- Use Starter ($7/month) or higher
- Or implement client-side reconnection retry with exponential backoff

For development, the free tier is fine.
