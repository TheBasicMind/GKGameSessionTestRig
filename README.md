# GKGameSession Test Rig

GKGameSession is a nice clean Apple API, but it suffers from a lack of documentation. Also though the API is clean there are a number of undocumented "gotchas" to be aware of. 

I wrote this test-rig in Swift to privide insight into the functioning of the GKGameSession API. To use the test-rig, compile and deploy it to two different iOS devices (or one iOS device and the simulator). Pressing each of the buttons will demonstrate how each GKGameSession API works. 

- Press "Get signed in" to get your player signed-in to an Game Kit iCloud gaming session for the current iCloud container.
- Press "Create Session" to create a new session, this will assigned to the *session* variable
- Press "List Sessions" to retreive a list of all sessions registered against the current players icloud account. Not the last session in this list will be assigned to the *session* variable replacing any other session stored there (though if you have just previously created a session, the same session will be the last in the list). The list of sessions will be stored against the sessions array
- The "Log Session" button doesn't execute an operation against the GKGameSession API, but it will log key details about the current session
- The "Save Data" buttons saves a data object containing either the string "Ice Cream" or "Apples" to the session stored against the *session* property
- The "Get Share URL" button gets the URL that can be used by another user to join a session. In fact it gets two URLs. One is the URL that is returned by the cloudkit API, the other is a URL the test rig constructs that can be used to overcome a limitation of the current API. With the current API joining a game doesn't automatically open the App. It is natural that if a friend sends a "Join me in this game" request, that you would like the recipient to be able to click on the link, the App open and the game be joined. Tapping the URL returned by the cloudkit API (e.g. in an iMessage or some other message) will join the game but won't start the App. The user has to do that separately. However by registering a URL that will open the app, and by then including the "join game" URL as an encoded paramateter appended to the first URL, it is possible to do both actions. The test rig demonstrates how. However there are some "gotchas" to be aware of, which are also reasonably straighforward to overcome, but that may not be obvious to those who are less familiar with iOS APIs and methods. 
- The "Load data for session" button loads the last set of data that has been saved by any of the players to the iCloud session
- The "Log session data" button doesn't execute an API call, but simply writes the contents of any data that has been loaded from the cloud to the log. Like for the session variable, there is a single gameData property which is used to cache the game data downloaded as a result of pressing the "Load data for session" button.
- The delete sessions button deletes all the sessions associated with the player. Any sessions the player owns are permanently deleted for all participants. Other participants are informed of the deletion through a call to session(_ session: GKGameSession, didRemove player: GKCloudPlayer). If the leaving player is the session owner, it can be deduced the session is also now deleted. 
- The "Manually Join Game" button is only enabled if the JoinAtStartup constant is set to false. When join at startup is set to true, if the user clicks on
- The message apponent button will send a message to all opponents who have joined the session (currently in this test rig I am limiting things to one apponent, but this is trivial to amend)
- The clear badge button will clear any badge associated with a player and set as a result of a message being sent

### General Notes and Gotchas

- If the same data is saved multiple times, the save will succeed, but other players will not get a save notification. Presumably Apple are comparing the stored data (or, more likely, a hash of the stored data) and only notifying other players of a save if the data has changed.

These are the "gotchas" I have learned about:

- After a game session is created, the game session owner display name is the name of the device owner. *But...*

- When a player signs in, the signed in player display name is the game centre player's "handle"

- If a player is not signed in, then for communications with any other session members, the player’s display name is null and the playerID id appears to be a temporary one. It is important to devise a scheme where this display name and ID is not used. 

The best way to do this is:

1. Ensuring a player is signed in before creating a game.

2. When opening the app to join a game delay joining the game until after the player is signed in. Then it will be possible to save directly to the iCloud session. Also the game owner will get a notification with all the user’s details present. The easiest way to do this is to store the join game URL in a variable (see the line `gameURL = url` in the app delegate) and then call `UIApplication.shared.open(gameURL, options: [:], completionHandler: nil)` on the successful completion of a call to `GKCloudPlayer.getCurrentSignedInPlayer(forContainer: container)`

- If a player creates a new game, saves data to it and then requests the session URL, the user can no longer save to the game session until another player has joined.

- When another player joins, there will be a false positive about the first player exiting the session. I suspect what is going on here is to do with the transition from the private to the public iCloud database. That the private database is copied to the public, but that the public can't be saved to until there are multiple users. And that the initial user is unsbsribed from the private database and resubscribed to the public as the change is made. Just a guess.

- If a player creates a new game, saves data to it and then requests the session URL, then another player joings the game, if the first player (the owner) deletes the session, the second player will still be able to save to the session, and there will be no error reported. However if either player requests to load the sessions he/she is a member of, the game session will no longer be in the list

- If a player saves data and the game is not running, clearly the opponent will not get the save notification. It is useful to be able to notify the other player to let that player know it is their turn. Fortunately sending a message will result in a GameKit notification being sent to the other player if the game is not running - all automatically (good job Apple, this saves a lot of work). Because of this nice benetit, I started saving data and immediately sending a message (before the completion handler of the save had been called). However if you do this, then the save will fail with a conflict, because the message, it seems, also updates the session object. This will then necessitate another save. Not good (though if you run into this problem it does have the dubious benefit of helping ensure you have your save error handling working well !). To avoid this problem, ensure the save data completion handling is done before the message is dispatched.


## Notes and Limitations

I set up the test rig to allow only two players to join because I am primarily interested in how it can be used to support turn based two player gaming. It can trivially be enhanced to test out the realtime gaming functions however.

I have implemented a simple hash algorithm to reduce the length of the Game Kit Game Session playerIDs. I did this becase the standard IDs make the log files so difficult to read. There is of course a 1 in 99,999,999 chance of a collision. If those odds sound bad to you and you think a collision will make debugging a problem then feel free to strip out the hashing! 

Generally I have kept the code as simple as possible. But I did also want to test out a simple Data encoding wrapper I developed to test encoded data matches a given API version. This is working well and I have left it in because it is easier to do so than strip it out and also it may prove useful to others (using such a wrapper is good practice - here's why):

When encoding objects to JSON for use with a cloud service such as iCloud, Swift's built in coder will check if the key paths of the object being decoded to, match the keys paths of the object that was used to encode in the first place.
 
container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey
 
However a matching set of key paths and types is insufficient for ensuring the API of the decoded object matches the API of the encoded object (e.g. it may only be value constraints that change). Additionally it is a good idea to maintain API versions such that on decoding, it is easy to know which version of the API a previously coded object was encoded using.
