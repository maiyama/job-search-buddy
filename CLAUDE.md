# Job-Search-Buddy -- AI buddy for your job search journey

## Project purpose
- Practice creating an app with AI so that I can learn something new and talk about it
- Streamline job search process by having one place to record and track progress
- Have an encouraging buddy on my side for emotional support

## User persona
- Job seeker who is eager to optimize their job search process
- Data driven
- Open to self-discovery

## Pain points
- Not knowing what's working and not working due to lack of visibility in what's been done and what has happened
- Having to jump between multiple applications to track the progress, schedule and outcomes
- Feeling overwhelmed and lonely in the process

## Functions
- User Input: Simple, text-based input of what's been done
- User Input: Update on application progress
- User Input: Comment about how the week went at the end of the week
- Output: Simple data dashboard of activities based on categories and time spent for a given range of time
- Output: Simple list of achivements
- Output: Encouraging message based on user's input

## UI
- Side bar contains: Activity Input, Dashboard, Companies

### Activity Input
- Main page that opens when the app is opened
- It contains a text box where user can type in text about their activity
- Use `reference/activity_example.csv` to categorize user's input into one of 5 activities (Review, Research, Interview, Application, Networking)
- Underneath of the text box, display time choice for user to input from what time to what time user did the activity. Make 'Now' option available
- Display Momo the seal buddy beside the text box (right panel). Momo's responses appear in the "Momo says..." scroll area below the illustration — no speech bubble on Momo directly
- After user specifies to-do for each day, display a check-box list of to-do activities that user can check boxes to indicate that they are done **Max 2 to-do items per day**
- Below Today's Goals, display This Week's Goals as a separate checkbox list

#### Input modes
Three input modes are supported via prefix in the text box:

| Prefix | What it does |
|---|---|
| *(none)* | Logs activity to Dashboard only. Companies table is NOT touched. |
| `[apply]` | Logs an `Application` activity to Dashboard AND adds/updates the company in the Companies table. |
| `[update]` | Updates the matching company's progress in the Companies table only. Nothing is logged to Dashboard. If the company is not found or the status is unclear, the input text is restored so the user can correct it. |

### Dashboard
- Display a simple pie chart of **time-based** activity breakdown (minutes per category, not entry count). Assign different color for each of 5 activities. Legend shows time (e.g. "1h 30m") and percentage.
- Let user choose time range for the pie chart. Options are a particular day, week, month or entire data. By default, display a week.
- Display stats for the selected time range:
    - **Applications Sent**: count of `Application`-type activity entries logged
    - **Interviews**: count of companies whose progress is currently `In-interview` (only increments when `[update]` moves a company to that state — NOT when "interview" is mentioned in a plain activity)
    - **Companies Tracked**: count of companies in the Companies table for the selected range
    - **Hours Spent**: total time logged across all activities

### Companies
- A simple table of companies user has sent applications
- The Companies table is **only updated** when the user uses `[apply]` or `[update]` prefixes in Activity Input. Plain activity entries never touch this table.
- Column names are: Name, Role, Contacts, Progress
    - Name: Company name (e.g. PointClickCare)
    - Role: Role user applied for (e.g. Senior PM)
    - Contacts: Any name associated with the company that user reached out
    - Progress: Depending on the progress of the application, pick one of choices below
        - 'Applied': State after user uses `[apply]`
        - 'Stale': State when 'Applied' state does not change for 3 weeks
        - 'In-interview': When user uses `[update]` and mentions interview
        - 'Gone': When user uses `[update]` and mentions rejection
        - 'Offer': When user uses `[update]` and mentions offer
        - 'Offer declined': When user uses `[update]` and mentions declining an offer
- Assign different color for each progress state

### Weekly review
- 3 text boxes at the top, each for feelings, wins, and opportunity for improvement
- A table of feelings about the week, wins and opportunity for improvements (OFPs)
- Column names are: Week, Feelings, Wins, OFPs
    - Week: date range, showing Monday - Friday (e.g. 5/4-5/8)
    - Feelings: Based on user input in the text box, describe the feelings in less than 30 words
    - Wins: User input under Wins. If it's longer than 30 words, summarize it
    - OFP: User input under OFPs. If it's longer than 30 words, summarize it
- For each section, there should be only one entry per week. If user added something within the same week, overwrite it.

## First session
**SAY:**

"Hi! I'm Momo. I'm your job search buddy. Could you tell me your name?"

**CHECK:** Wait for user response

**When user respond with a name**
Take this name as user name and use it to greet user each day.

## Daily FLow

- At the beginning of each day, greet and **ASK:**

"What are top one or two things you want to accomplish today? Be specific!"

- When user completes all tasks in the to-do list, display confetti over the screen to celebrate

- When user types 'review', this indicates the end of the day. **ASK:**

"Another day done! How do you feel?"
**ACTION:** Give encouraging comments to user