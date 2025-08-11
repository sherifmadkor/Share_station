# Game Database Setup Guide

## Overview
The Share Station app uses the RAWG Video Games Database API to provide comprehensive game title validation and suggestions. This ensures users can only select from official PS4/PS5 games, preventing naming discrepancies.

## Features
- **Comprehensive Game Database**: Access to thousands of PS4/PS5 games
- **Auto-completion**: Smart search suggestions as users type
- **Validation**: Only official game titles can be selected
- **Offline Fallback**: Cached games work without internet
- **Existing Games Priority**: Shows user's existing games first

## API Setup Instructions

### Step 1: Get RAWG API Key
1. Visit [RAWG API Documentation](https://rawg.io/apidocs)
2. Click **"Get API Key"**
3. Create a free account
4. Go to your dashboard to find your API key

### Step 2: Configure API Key
1. Open `lib/config/api_config.dart`
2. Replace `YOUR_RAWG_API_KEY` with your actual API key:
```dart
static const String rawgApiKey = 'your-actual-api-key-here';
```

### Step 3: Verify Configuration
The app will automatically:
- Validate the API key on startup
- Use cached games if API is unavailable
- Display appropriate error messages

## API Limits (Free Tier)
- **5,000 requests per month**
- **Rate limit**: Reasonable usage
- **Automatic caching**: Reduces API calls

## How It Works

### 1. Game Search Flow
```
User types → Search existing games → Search RAWG API → Cache results → Display combined results
```

### 2. Game Selection
```
User selects game → Validate selection → Store game info → Enable contribution submission
```

### 3. Contribution Process
```
Validated game → Create contribution request → Admin approval → Add to game library
```

## File Structure
```
lib/
├── config/
│   └── api_config.dart          # API configuration
├── services/
│   └── game_database_service.dart # Game database service
└── presentation/screens/user/
    └── add_contribution_screen.dart # Enhanced contribution form
```

## Troubleshooting

### API Key Issues
- **Error**: "RAWG API key is not configured"
  - **Solution**: Set your API key in `lib/config/api_config.dart`

- **Error**: "Invalid RAWG API key"
  - **Solution**: Check your API key is correct and active

### No Game Results
- **Issue**: Search returns no results
  - **Check**: Internet connection
  - **Check**: API key is valid
  - **Note**: App will use cached games as fallback

### Performance
- **First search**: May be slower (fetching from API)
- **Subsequent searches**: Fast (cached results)
- **Popular games**: Pre-cached for instant results

## Benefits

### For Users
- **Easy Game Selection**: Type and select from official games
- **No Typos**: Prevents game name errors
- **Rich Information**: See game ratings, platforms, release dates

### For Admins
- **Consistent Data**: All games have standardized names
- **Better Organization**: Games properly grouped and categorized
- **Quality Control**: Only official games in the system

## Testing
1. Open the app
2. Go to "Add Contribution" → "Game Account"
3. Type a game name (e.g., "God of War")
4. Verify suggestions appear with game details
5. Select a game and ensure it's marked as selected

## Production Deployment
- The API key is included in the compiled app
- Consider using environment variables for enhanced security
- Monitor API usage in RAWG dashboard
- Set up proper error handling for API failures

## Support
For issues with the game database integration:
1. Check the console logs for error messages
2. Verify API key configuration
3. Test with popular game names first
4. Ensure internet connectivity for initial setup