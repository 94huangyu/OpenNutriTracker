/// Remote search waits for a typing pause; local search runs immediately.
const searchDebounceDuration = Duration(milliseconds: 500);

/// Every nonblank input searches locally, including a single Chinese character.
const minQueryLength = 2;
