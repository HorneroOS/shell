.pragma library

// Curated offline Unicode emoji dataset and search (HorneroOS/shell#737).
// Pure JS module — no subprocesses, no external plugins required.

var EMOJIS = [
    // Smileys & Expressions
    { "char": "😀", "name": "Grinning Face", "category": "Smileys", "keywords": "smile happy grin joy" },
    { "char": "😂", "name": "Face with Tears of Joy", "category": "Smileys", "keywords": "laugh lol funny cry" },
    { "char": "🥹", "name": "Face Holding Back Tears", "category": "Smileys", "keywords": "touched proud cute" },
    { "char": "😊", "name": "Smiling Face with Smiling Eyes", "category": "Smileys", "keywords": "blush warm happy" },
    { "char": "😉", "name": "Winking Face", "category": "Smileys", "keywords": "wink playful" },
    { "char": "😍", "name": "Smiling Face with Heart-Eyes", "category": "Smileys", "keywords": "love heart adore" },
    { "char": "🥰", "name": "Smiling Face with Hearts", "category": "Smileys", "keywords": "love affectionate" },
    { "char": "😎", "name": "Smiling Face with Sunglasses", "category": "Smileys", "keywords": "cool shades chill" },
    { "char": "🤔", "name": "Thinking Face", "category": "Smileys", "keywords": "hmm wonder question ponder" },
    { "char": "🫡", "name": "Saluting Face", "category": "Smileys", "keywords": "salute respect aye" },
    { "char": "🥳", "name": "Partying Face", "category": "Smileys", "keywords": "party celebrate birthday" },
    { "char": "😴", "name": "Sleeping Face", "category": "Smileys", "keywords": "sleep zzz tired nap" },
    { "char": "🤯", "name": "Exploding Head", "category": "Smileys", "keywords": "mind blown shocked" },
    { "char": "😭", "name": "Loudly Crying Face", "category": "Smileys", "keywords": "cry sad sob" },
    { "char": "😅", "name": "Grinning Face with Sweat", "category": "Smileys", "keywords": "phew relief nervous" },
    { "char": "🙃", "name": "Upside-Down Face", "category": "Smileys", "keywords": "sarcasm silly" },
    { "char": "🫠", "name": "Melting Face", "category": "Smileys", "keywords": "melt awkward hot" },
    { "char": "😤", "name": "Face with Steam From Nose", "category": "Smileys", "keywords": "triumph frustrated huff" },
    { "char": "😡", "name": "Enraged Face", "category": "Smileys", "keywords": "angry mad" },
    { "char": "🤓", "name": "Nerd Face", "category": "Smileys", "keywords": "geek glasses smart" },
    { "char": "🤩", "name": "Star-Struck", "category": "Smileys", "keywords": "wow excited starry" },
    { "char": "😬", "name": "Grimacing Face", "category": "Smileys", "keywords": "awkward yikes" },
    { "char": "🤫", "name": "Shushing Face", "category": "Smileys", "keywords": "quiet secret shh" },

    // Gestures & Hands
    { "char": "👍", "name": "Thumbs Up", "category": "Gestures", "keywords": "ok yes approve like plus" },
    { "char": "👎", "name": "Thumbs Down", "category": "Gestures", "keywords": "no dislike reject" },
    { "char": "👏", "name": "Clapping Hands", "category": "Gestures", "keywords": "applause bravo clap" },
    { "char": "🙌", "name": "Raising Hands", "category": "Gestures", "keywords": "celebrate hooray praise" },
    { "char": "🙏", "name": "Folded Hands", "category": "Gestures", "keywords": "please thanks pray" },
    { "char": "🤝", "name": "Handshake", "category": "Gestures", "keywords": "deal agree partner" },
    { "char": "✌️", "name": "Victory Hand", "category": "Gestures", "keywords": "peace two" },
    { "char": "🤞", "name": "Crossed Fingers", "category": "Gestures", "keywords": "luck hope" },
    { "char": "💪", "name": "Flexed Biceps", "category": "Gestures", "keywords": "strong power muscle" },
    { "char": "👋", "name": "Waving Hand", "category": "Gestures", "keywords": "hello hi bye wave" },
    { "char": "👌", "name": "OK Hand", "category": "Gestures", "keywords": "perfect fine ok" },
    { "char": "🫶", "name": "Heart Hands", "category": "Gestures", "keywords": "love care hands" },
    { "char": "👀", "name": "Eyes", "category": "Gestures", "keywords": "look watch see peek" },

    // Hearts & Status Symbols
    { "char": "❤️", "name": "Red Heart", "category": "Symbols", "keywords": "love heart" },
    { "char": "🧡", "name": "Orange Heart", "category": "Symbols", "keywords": "love heart orange" },
    { "char": "💛", "name": "Yellow Heart", "category": "Symbols", "keywords": "love heart yellow" },
    { "char": "💚", "name": "Green Heart", "category": "Symbols", "keywords": "love heart green" },
    { "char": "💙", "name": "Blue Heart", "category": "Symbols", "keywords": "love heart blue" },
    { "char": "💜", "name": "Purple Heart", "category": "Symbols", "keywords": "love heart purple" },
    { "char": "🔥", "name": "Fire", "category": "Symbols", "keywords": "hot flame lit streak" },
    { "char": "✨", "name": "Sparkles", "category": "Symbols", "keywords": "magic shine new clean" },
    { "char": "⭐", "name": "Star", "category": "Symbols", "keywords": "favorite star" },
    { "char": "⚡", "name": "High Voltage", "category": "Symbols", "keywords": "fast lightning zap energy" },
    { "char": "💯", "name": "Hundred Points", "category": "Symbols", "keywords": "100 perfect score" },
    { "char": "✅", "name": "Check Mark Button", "category": "Symbols", "keywords": "done pass ok check yes" },
    { "char": "❌", "name": "Cross Mark", "category": "Symbols", "keywords": "fail error no close x" },
    { "char": "⚠️", "name": "Warning", "category": "Symbols", "keywords": "alert caution warn" },
    { "char": "ℹ️", "name": "Information", "category": "Symbols", "keywords": "info help" },
    { "char": "❓", "name": "Red Question Mark", "category": "Symbols", "keywords": "question ask" },
    { "char": "❗", "name": "Red Exclamation Mark", "category": "Symbols", "keywords": "important alert bang" },
    { "char": "🚀", "name": "Rocket", "category": "Travel", "keywords": "launch ship deploy fast space" },
    { "char": "🎉", "name": "Party Popper", "category": "Activities", "keywords": "tada celebrate release congrats" },
    { "char": "🏆", "name": "Trophy", "category": "Activities", "keywords": "win award prize" },
    { "char": "🎯", "name": "Bullseye", "category": "Activities", "keywords": "target goal focus hit" },

    // Tech, Dev & Objects
    { "char": "💻", "name": "Laptop", "category": "Objects", "keywords": "computer code dev pc" },
    { "char": "⌨️", "name": "Keyboard", "category": "Objects", "keywords": "type keybinds input" },
    { "char": "🖥️", "name": "Desktop Computer", "category": "Objects", "keywords": "monitor screen display" },
    { "char": "🐛", "name": "Bug", "category": "Objects", "keywords": "bug issue insect debug" },
    { "char": "🔧", "name": "Wrench", "category": "Objects", "keywords": "fix tool repair config" },
    { "char": "⚙️", "name": "Gear", "category": "Objects", "keywords": "settings config system" },
    { "char": "🛠️", "name": "Hammer and Wrench", "category": "Objects", "keywords": "build tools maintain" },
    { "char": "🔒", "name": "Locked", "category": "Objects", "keywords": "lock security private" },
    { "char": "🔓", "name": "Unlocked", "category": "Objects", "keywords": "unlock open" },
    { "char": "🔑", "name": "Key", "category": "Objects", "keywords": "key auth secret token" },
    { "char": "📌", "name": "Pushpin", "category": "Objects", "keywords": "pin note remember" },
    { "char": "📎", "name": "Paperclip", "category": "Objects", "keywords": "attach clip file" },
    { "char": "📋", "name": "Clipboard", "category": "Objects", "keywords": "copy paste notes" },
    { "char": "📝", "name": "Memo", "category": "Objects", "keywords": "write note edit doc" },
    { "char": "📁", "name": "File Folder", "category": "Objects", "keywords": "directory folder" },
    { "char": "🔍", "name": "Magnifying Glass", "category": "Objects", "keywords": "search find zoom" },
    { "char": "🧪", "name": "Test Tube", "category": "Objects", "keywords": "test lab experiment" },
    { "char": "📦", "name": "Package", "category": "Objects", "keywords": "box build release pkg" },
    { "char": "🧠", "name": "Brain", "category": "Objects", "keywords": "smart ai think mind" },
    { "char": "🤖", "name": "Robot", "category": "Objects", "keywords": "bot automation ai" },
    { "char": "⏱️", "name": "Stopwatch", "category": "Objects", "keywords": "timer speed benchmark" },
    { "char": "📅", "name": "Calendar", "category": "Objects", "keywords": "date schedule event" },
    { "char": "🔔", "name": "Bell", "category": "Objects", "keywords": "notification alert ring" },
    { "char": "🔕", "name": "Bell with Slash", "category": "Objects", "keywords": "mute dnd silent" },

    // Nature, Weather & Food
    { "char": "🐦", "name": "Bird", "category": "Nature", "keywords": "hornero bird avian" },
    { "char": "🪶", "name": "Feather", "category": "Nature", "keywords": "hornero feather light" },
    { "char": "🌞", "name": "Sun with Face", "category": "Nature", "keywords": "sun day bright light" },
    { "char": "🌙", "name": "Crescent Moon", "category": "Nature", "keywords": "moon night dark" },
    { "char": "☁️", "name": "Cloud", "category": "Nature", "keywords": "cloud weather" },
    { "char": "🌧️", "name": "Cloud with Rain", "category": "Nature", "keywords": "rain weather" },
    { "char": "❄️", "name": "Snowflake", "category": "Nature", "keywords": "snow cold winter" },
    { "char": "🌈", "name": "Rainbow", "category": "Nature", "keywords": "rainbow colors pride" },
    { "char": "🌱", "name": "Seedling", "category": "Nature", "keywords": "plant grow green" },
    { "char": "☕", "name": "Hot Beverage", "category": "Food", "keywords": "coffee tea cafe morning" },
    { "char": "🧉", "name": "Mate", "category": "Food", "keywords": "mate argentina drink" },
    { "char": "🍕", "name": "Pizza", "category": "Food", "keywords": "pizza food" },
    { "char": "🍺", "name": "Beer Mug", "category": "Food", "keywords": "beer cheers drink" },

    // Arrows & Typography
    { "char": "→", "name": "Rightwards Arrow", "category": "Typography", "keywords": "arrow right next" },
    { "char": "←", "name": "Leftwards Arrow", "category": "Typography", "keywords": "arrow left back" },
    { "char": "↑", "name": "Upwards Arrow", "category": "Typography", "keywords": "arrow up" },
    { "char": "↓", "name": "Downwards Arrow", "category": "Typography", "keywords": "arrow down" },
    { "char": "↗", "name": "North East Arrow", "category": "Typography", "keywords": "arrow external link" },
    { "char": "—", "name": "Em Dash", "category": "Typography", "keywords": "dash punctuation" },
    { "char": "•", "name": "Bullet", "category": "Typography", "keywords": "dot bullet separator" },
    { "char": "…", "name": "Horizontal Ellipsis", "category": "Typography", "keywords": "ellipsis dots" },
    { "char": "°", "name": "Degree Sign", "category": "Typography", "keywords": "degree temp angle" },
    { "char": "×", "name": "Multiplication Sign", "category": "Typography", "keywords": "times multiply cross" },
    { "char": "≈", "name": "Almost Equal To", "category": "Typography", "keywords": "approx math" },
    { "char": "≠", "name": "Not Equal To", "category": "Typography", "keywords": "not equal math" }
];

function searchEmojis(query, limit) {
    var cap = typeof limit === "number" && limit > 0 ? limit : 50;
    var q = String(query || "").trim().toLowerCase();
    if (q.length === 0)
        return EMOJIS.slice(0, cap);

    var tokens = q.split(/\s+/).filter(function (t) { return t.length > 0; });
    var exact = [];
    var prefix = [];
    var nameMatch = [];
    var keywordMatch = [];

    for (var i = 0; i < EMOJIS.length; i++) {
        var item = EMOJIS[i];
        var nameLower = item.name.toLowerCase();
        var catLower = item.category.toLowerCase();
        var kwLower = item.keywords.toLowerCase();
        var allText = item["char"] + " " + nameLower + " " + catLower + " " + kwLower;

        var matchedAll = true;
        for (var j = 0; j < tokens.length; j++) {
            if (allText.indexOf(tokens[j]) === -1) {
                matchedAll = false;
                break;
            }
        }
        if (!matchedAll)
            continue;

        if (item["char"] === q || nameLower === q)
            exact.push(item);
        else if (nameLower.indexOf(q) === 0)
            prefix.push(item);
        else if (nameLower.indexOf(q) !== -1)
            nameMatch.push(item);
        else
            keywordMatch.push(item);
    }

    return exact.concat(prefix, nameMatch, keywordMatch).slice(0, cap);
}
