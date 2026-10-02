# sagun_advmobprog

A new Flutter project.

## Lab Activity 4: discussion

### How the user model, service, and screens interact to render the profile screen

`User` (`lib/models/user.dart`) is a plain data class that mirrors the shape
of the dummyjson `/auth/login` response (`id`, `username`, `email`,
`firstName`, `lastName`, `gender`, `image`, `accessToken`, `refreshToken`),
with a `fromJson`/`toJson` pair so it can move between the API,
`SharedPreferences`, and the widgets.

`UserService` (`lib/services/user_service.dart`) is the only layer that talks
to the network and to local storage:

1. `loginUser(username, password)` POSTs to `$host/auth/login` and, on a 200
   response, immediately calls `saveUserData` so the session survives an app
   restart.
2. `saveUserData(Map)` converts the raw JSON into a `User` and writes each
   field into `SharedPreferences` as individual primitives (`setInt`,
   `setString`, ...), since `SharedPreferences` can't store nested objects.
3. `getUserData()` reads those primitives back into a `Map`, and `getUser()`
   wraps that map back into a `User` via `User.fromJson` — the same model
   used on login, now rehydrated from disk instead of the network.
4. `isLoggedIn()` and `logout()` let `SplashScreen` and `ProfileScreen` check
   or clear the persisted session without knowing anything about
   `SharedPreferences` directly.

`ProfileScreen` (`lib/screens/profile_screen.dart`) calls
`UserService().getUser()` in a `FutureBuilder`. When it resolves, the
resulting `User` object is rendered directly into the avatar, name,
`@username`, email, gender, and user-ID rows — no separate API call is
needed for the profile screen itself, because `getUser()` reads from the
same `SharedPreferences` values that were saved right after login. Tapping
**Log Out** calls `UserService.logout()` (which clears `SharedPreferences`)
and routes back to `/signin`.

### The updated design pattern

This activity turns the project into a proper layered structure:

- **models/** (`user.dart`, `product.dart`, `cart.dart`) — dumb data holders
  with `fromJson`/`toJson`, no Flutter widgets or business logic.
- **services/** (`user_service.dart`, `product_service.dart`,
  `cart_service.dart`) — all `http` calls and, for `user_service.dart`, all
  `SharedPreferences` persistence. Screens never call `http` or
  `SharedPreferences` directly.
- **providers/** (`theme_provider.dart`) — app-wide state (theme) exposed via
  `ChangeNotifier`/`provider` to any widget that needs it.
- **screens/** — UI only. Each screen owns a service instance, calls it in
  `initState`/handlers, and renders whatever `Future`/state it gets back.
- **widgets/** (`custom_text.dart`) — small reusable UI pieces shared across
  screens.

The new pieces added for this activity (`splash_screen.dart`,
`signin_screen.dart`, `profile_screen.dart`, `user.dart`,
`user_service.dart`) slot into the exact same pattern as the Lab 3 code
(`product_screen.dart`/`product_service.dart`/`product.dart` and
`cart_screen.dart`/`cart_service.dart`/`cart.dart`), so authentication is
just another model/service/screen triplet rather than a special case.

Navigation was also updated to reflect persistent auth: `main.dart`'s
`initialRoute` now points at `/splash` instead of `/home`. `SplashScreen`
waits briefly, asks `UserService.isLoggedIn()`, and routes to `/home` (with
the saved user data as route arguments) if a session exists, or to
`/signin` otherwise. `SigninScreen` calls `UserService.loginUser` and, on
success, routes to `/home` with the fresh login response as arguments.

### Rendering the cart by user ID

`HomeScreen` now receives the signed-in user's data as its route arguments
(`Map<String, dynamic>? userData`) and reads `userData?['id']` as `_userId`.
That `_userId` is passed down as a `userId` constructor parameter to both
`ProductScreen` and `CartScreen`, replacing the old hardcoded
`currentUserId` constant from Lab 3.

`CartScreen` uses that `userId` to call
`CartService.getCartByUserId(userId)`, which hits
`$host/carts/user/{userId}` and returns only the cart that belongs to the
signed-in account. Because `userId` now comes from the persisted login
session instead of a constant, each signed-in user sees their own cart, and
adding an item (`DetailScreen._addToCart`) also posts to
`CartService.addToCart(userId, ...)` using that same ID — so the item and
the cart it lands in are always tied to whoever is actually logged in.

## Lab Activity 5: discussion

### Workflow: DummyJSON vs Firebase, from sign-in to sign-up

**DummyJSON (REST).** The app owns the whole session.
1. `SigninScreen` sends the username and password to
   `UserService.loginUser`, which POSTs to `$host/auth/login`.
2. On a 200 response the server returns the user plus `accessToken` and
   `refreshToken`. `saveUserData` writes them to `SharedPreferences`, and the
   session is marked `loginType = dummyJson`.
3. On the next launch `SplashScreen` calls `isLoggedIn()`, which only checks that
   a token string exists locally. Nothing validates it or refreshes it when it
   expires (`expiresInMins: 60`).
4. DummyJSON has no real sign-up. `POST /users/add` fakes a user and doesn't
   persist it, so nobody can actually register and log back in.

**Firebase Auth (SDK).** Google's servers own the session.
1. **Sign-up:** `SignupScreen` validates fName, lName, age, contactNo, username,
   emailAddress and password (8+ chars with upper, lower and a digit). It calls
   `createAccount` (`createUserWithEmailAndPassword`), then `updateUsername`
   (sets the Firebase `displayName`) and `saveFirebaseProfile` (stores the fields
   Firebase Auth has no slot for, keyed by uid).
2. **Sign-in:** `SigninScreen` has a DummyJSON / Firebase selector. In Firebase
   mode it calls `signIn` (`signInWithEmailAndPassword`) and marks the session
   `loginType = firebase`.
3. **Session and token refresh:** the SDK persists the signed-in user itself and
   restores it on startup, so `isLoggedIn()` just checks `currentUser != null`.
   `getUserData()` calls `user.getIdToken()`, which silently refreshes the ID
   token once it expires, so the app never handles refresh logic.
4. **Account management:** `updateUsername`, `resetPasswordFromCurrentPassword`
   and `deleteAccount` act on the real account. The last two re-authenticate
   first because Firebase requires a recent login for sensitive changes.
5. **Sign-out:** `logout()` calls `FirebaseAuth.signOut()` and clears the saved
   session. It is reachable from the Profile tab and from Settings.

### The main idea of `UserService`

`UserService` is the single facade the screens use for identity. Screens never
touch `http`, `SharedPreferences` or `FirebaseAuth` directly, and they call the
same methods (`getUserData`, `getUser`, `isLoggedIn`, `logout`) whichever back
end is behind them. The `LoginType` enum records which back end owns the session
so those shared methods can branch internally, and `ProfileScreen` uses it to
decide what to show: DummyJSON gets a read-only profile (email, gender, id),
Firebase gets age, contact, uid and the update/change-password/delete actions.
Adding a third provider would mean adding a `LoginType` value and its methods
here, without rewriting the UI.

### Benefits of Firebase in this application

- **Real registration.** Users can sign up and sign back in. DummyJSON only has
  a fixed list of test accounts.
- **No password handling in our code.** Firebase hashes and stores credentials
  and throttles brute-force attempts (`too-many-requests`).
- **Managed tokens.** ID tokens are short-lived and refreshed by the SDK. The
  DummyJSON token here sits in plain `SharedPreferences` and is never checked.
- **Account lifecycle out of the box.** Username update, password change and
  account deletion are single SDK calls.
- **Session survives restarts** without our own persistence code.
- **Security rules.** If Firestore or Storage is added later, rules can restrict
  data to `request.auth.uid`, so the back end enforces who can read or write what.
- **No server to build or host**, and it works on Android and iOS from one
  Flutter API.

### Notes

- Firebase users have no DummyJSON cart, so the cart tab has nothing for them
  (their `id` is `0`). Moving carts into Firestore would be the next step.

## Lab Activity 6: discussion

### Why Firestore, and why it replaces the Cart tab

Lab 5 added Firebase Auth for identity; Lab 6 adds **Cloud Firestore**
(`cloud_firestore`) as the first real-time, shared database in the app, used
to build a one-to-one chat between signed-in Firebase users. The assignment
sheet's enhancement list explicitly calls for revising the **second
`BottomNavigationBarItem`** (previously Cart, shown with `Icons.shopping_cart`)
into the chat list, so `HomeScreen`'s `PageView` now renders
`ProductScreen` → `ChatScreen` → `ProfileScreen`, and the item's icon changed
to `Icons.chat_bubble`. `CartScreen`/`CartService` still exist (DummyJSON
carts are untouched) but are no longer reachable from navigation.

### The model/service/screen chain for chat

`MessageModel` (`lib/models/message.dart`) mirrors one document in a chat
room's `messages` subcollection: `senderId`, `senderEmail`, `receiverId`,
`message`, and a Firestore `Timestamp`, with the usual `fromMap`/`toMap`
pair.

`ChatService` (`lib/services/chat_service.dart`) is the only layer that talks
to Firestore for chat, mirroring how `UserService` is the only layer that
talks to `http`/`SharedPreferences`/`FirebaseAuth`:

1. `getUsersStream()` streams every document in the `Users` collection — the
   directory `ChatScreen` lists from.
2. `sendMessage(receiverId, message)` writes the new message into
   `chat_rooms/{chatRoomID}/messages`, where `chatRoomID` is the two users'
   uids sorted and joined with `_` (`_chatRoomId`). Sorting first means the
   same two people always land in the same room regardless of who opens the
   chat first. It also upserts a summary onto the `chat_rooms/{chatRoomID}`
   document itself (`lastMessage`, `lastMessageTime`, `lastSenderId`,
   `participants`, `readBy: [senderId]`) — see unread tracking below.
3. `getMessages(userId, otherUserId)` streams that room's `messages`
   subcollection ordered newest-first, which `ChatDetailScreen` renders with
   `reverse: true` so the list reads bottom-up like a normal chat app.
4. `markAsRead`/`getChatRoomInfo`/`hasUnreadMessages` all read or write that
   same summary document rather than the message history, so checking
   "is this unread" never requires loading every message in a room.

Firestore doesn't store a Firebase Auth user's email/name on its own, so
`UserService._syncFirestoreUser()` mirrors `uid`/`email`/`firstName`/
`lastName` into `Users/{uid}` on both signup (`saveFirebaseProfile`) and
sign-in — the sign-in call backfills the collection for accounts created
before chat existed, so every Firebase user eventually shows up in the chat
list without a one-off migration script.

### Chat List and Chat Detail screens

`ChatScreen` (Enhancement 1 & 2) streams `getUsersStream()`, filters out the
signed-in user (`uid == _currentUserUid`), and applies a client-side search
against the typed text (lowercased, matched against the full name and
email). Each row also opens a second `StreamBuilder` on
`getChatRoomInfo(currentUserUid, otherUid)` purely to decide whether to show
the unread dot and preview — explained below.

`ChatDetailScreen` (Enhancement 3) redesigns the bubble layout: the signed-in
user's messages are right-aligned and filled with the app's indigo accent,
the other person's are left-aligned and grey, and the trailing corner on
each bubble's "pointer" side is squared off instead of rounded so the two
senders read as visually distinct at a glance. Each bubble wraps in a
`TweenAnimationBuilder` that fades and slides in from a few pixels below
(`Opacity` + `Transform.translate`) as it first builds, and the composer
row shows a `CircularProgressIndicator` in place of the send button plus a
"Sending..." caption (`AnimatedSwitcher`) while `sendMessage`'s future is in
flight, then a `done_all` checkmark on the most recent outgoing bubble once
it lands.

### Unread-message indicator

Firestore has no built-in "unread count," so it's modeled explicitly on the
`chat_rooms/{chatRoomID}` document instead of the subcollection:

- `readBy` is a list of uids who have seen the room's `lastMessage`. Sending
  a message resets it to `[senderId]` — only the sender has "read" their own
  message.
- Opening a conversation calls `ChatService.markAsRead(myUid, otherUid)`,
  which does `readBy: FieldValue.arrayUnion([myUid])` in `initState`, so the
  badge clears the moment the chat is opened.
- A room counts as unread for a user when `lastSenderId != myUid` (someone
  else sent the last message) **and** `myUid` is not in `readBy` yet.

This one field is read in two places: `ChatScreen` shows a small red dot on
the avatar plus a bolded name/last-message preview per conversation, and
`HomeScreen`'s `_ChatTabIcon` runs a broader query
(`hasUnreadMessages`, `participants arrayContains myUid`) to put the same red
dot on the Chat tab's bottom-nav icon — so an unread message is visible
without opening the tab at all.

### Notes

- Firestore rules started as the lab-instructed `allow read, write: if true`
  (needed to get the Rules tab published at all), then were tightened to
  `allow read, write: if request.auth != null` (see `firestore.rules`,
  deployed with `firebase deploy --only firestore:rules`) once the repo went
  public on GitHub — an open-to-everyone rule plus a public project ID is a
  real way for strangers to read/write the database, not just a theoretical
  risk. Requiring sign-in doesn't break anything here since only signed-in
  Firebase users ever touch Firestore (chat).
- `lib/firebase_options.dart` (and `android/app/google-services.json`)
  contain Firebase's client `apiKey` values and are committed on purpose —
  Firebase treats these as app identifiers, not secrets; the security
  boundary is the rules above, not hiding this file. GitHub's secret
  scanner still flags them as "Google API Key" on its generic pattern
  match, which is why the rules fix above (not deleting/rotating the key)
  is the actual remediation; the alert can be dismissed afterward.
- `assets/.env` is git-ignored; see `assets/.env.example` for the keys the
  app expects (`HOST`, `API_KEY`) and copy it to `assets/.env` locally.
