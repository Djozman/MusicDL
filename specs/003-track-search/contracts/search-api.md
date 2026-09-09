# Interface Contract: Track Search

The Swift frontend calls the `search.py` backend helper, which returns a JSON results
array. No backend changes beyond the new helper.

## `search.py <query>`

### Success (`type: "search_results"`)
```json
{
  "type": "search_results",
  "query": "drake gods plan",
  "results": [
    {
      "title": "God's Plan",
      "artist": "Drake",
      "album": "Scorpion",
      "artwork_url": "https://is1-ssl.mzstatic.com/...600x600bb.jpg",
      "track_url": "https://open.spotify.com/track/6DCZcSspjsKoFjzjrWoCdn",
      "source": "itunes"
    }
  ]
}
```

### Error (`type: "error"`)
```json
{ "type": "error", "message": "No results found" }
```

### Frontend flow
- User types a query → app calls `search.py <query>`.
- On result, the app renders artwork/title/artist in `SearchResultsView`.
- On tap, the app sets `inputURL = result.track_url` (fall back to a resolvable source)
  and calls the existing `submitURL()`/download flow.
- The existing adaptive status text ("Downloading track <name> to ~/Music") is reused.