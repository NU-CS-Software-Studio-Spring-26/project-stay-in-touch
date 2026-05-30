# Milestone 4 and final exam presentation

The final exam will consist of a public presentation of your project work. Feel free to invite your friends and family to the presentation. 

The  target project state is a release of a publicly available professionally looking and working product that you are proud of. This includes many dimensions, many of them are listed below. 

# Technical requirements 

##  Functional basics

1. Functionally, the project should at minimum be the functionality of containing at least two models with associations correctly implemented, plus several functional improvements since MVP presentation.Data for at least one model should include images, such as user photo, organization logo, movie poster, etc.and use ActiveStorage or another modern storage solution (e.g. AWS S3)  
2. All unfinished functionality should be completed or removed without a trace.  
3. Users and user’s application management (e.g. dashboard) should be implemented.   
4. Authorization and authentication are working correctly. Password-protected pages should not be accessible via a hyperlink. The app allows registration with username password and standard functionality (password reminder, changing password, deleting account). Third-party authentication is implemented.   
5. There are at least 3n (n \= team size) real users. Fake user data (“User 1” or “ppp”) is deleted. The website should be prepared to work for a thousand users each producing a thousand entries (or a limit allowed by your app). Pagination should be implemented (with at least 24 entries/page).  
6. JavaScript is used on the front end where appropriate (can be input validation, tooltips, hide/show, navigation elements, etc).  Best design principles are followed (Intuitive navigation, ease of reading, style uniformity, explanations of the rules, fast feedback for user actions, making decision-making simple, anticipating and forgiving mistakes). This includes, but is not limited to, simplifying users’ input with dropdown menus, radiobuttons, default values, and field hints, ability to sort table columns by many fields, pagination, flash notifications, use of standard icons.   Asynchronous background requests are implemented where needed (no unnecessary page reloads).   
7. Input is validated both on the client and on the server side. Incorrect user input doesn’t crash the database. This includes minimal security considerations, e.g. not letting user enter 5GB of data in name field or run SQL injection.  
8. Each member of the team should implement one or two “neat” features using gems and external APIs such as downloading data as pdf or similar data import/export, data visualization on a map, email notifications, liking/ranking, keywords/tagging, using gravatars, attachments, payment processing, data encryption, search, scheduling tasks, building/displaying reports/graphs/charts, internal chat/messaging system, discussion board, word counting/statistics, RSS feed, or whatever makes sense for your application. (as required for Milestone 3\)  
9. At minimum ceiling(n/2) (n= team size), ideally more, trust and safety features are implemented. This could include flagging/reporting inappropriate content, checking for profanity, prohibiting inappropriate images or prompts, rate limiting new submissions including captchas, creating clear community guidelines page, requiring users to accept the terms on signup. Recommended gems obscenity (profanity filtering),  rack-attack (rate limiting), aws-sdk-rekognition (image moderation), akismet (spam detection).   
10. Each member of the team should implement at least one JavaScript improvement (client-side input validation, tooltip, hide/show, navigation elements, etc)   
11. Each member of the team should implement at least one HTML/CSS accessibility improvement, such as alt text, high contrast, tab navigation, ARIA labels,  etc  
12. App runs as a PWA (progressive web app) on a mobile platform.

## Process quality

### AI-Assisted test-driven development

13. At this phase AI should be fully integrated into development. The process should include formulating features, converting them to cucumber tests, writing RSpec tests for them, and assigning Issues to Copilot in Github to complete the code. Each team member should assign at least one issue to the AI assistant and verify its correct implementation through code review and testing. 

### Project management

14. Consistent progress with the project. Commits at minimum every other day, ideally every day. Contributions of all team members are evident. Balanced team contributions.   
15. The final version of the code on Heroku. All features except known issues (email notifications) should be testable on Heroku.   
16. The final version of the code is on Github; only one active branch (main) exists on Github. All Github issues are addressed or closed with a comment.  Meaningful commit messages on Github, using convention. All work through PR workflow (no direct commits to main).  Final version tagged.      
17. Project board (Github project) in sync with project:

    All implemented features marked Done 

    ToDo should contain at least 5 stories describing one or two immediate future improvements that you are not implementing in this class but would be a very logical next step. Leave everything else on the Icebox.

18. Continuous Integration on Github is required. Main branch protection should be set up. 

### Code and data quality

19.  Code is DRY, repeating functionality is in partials, filters, and private methods. Linters are applied to code.   
20.   Code is self-documenting and well-commented. Non-functional code is removed without a trace. RDoc documentation is generated.   
21.  Frontend is using a popular framework (Bootstrap or its analog). Website’s look is clean and professional throughout.  
22. Data present in the public-facing website should be or appear meaningful and diverse (can be generated by tools like Faker but should not be ‘bbb’ or ‘123’).

### Testing

23. Cucumber tests present requirements (both happy and sad scenarios).  
24. Each member of the team should cover at least one feature with RSpec tests.   
25. UI should be evaluated on at least two different browsers (most recent version installable on your machine), both on desktop and mobile.  

  


# Presentation

The presentation should cover two categories \- your project, and your learning summary. 

### Project work

Briefly describe the task the website is solving (your elevator pitch). 

1. Demonstrate the correct operation of your site from login to logout. Highlight special thoughtful features and improvements as you go but don’t disturb the flow. Demonstration should run from Heroku. Local demo is only allowed for special features that require subscriptions and have similar obstacles.   
2. Describe one major problem (technical or conceptual) that you encountered while working on the site and how you resolved it, mention when it happened.   
3. Open your project board and demonstrate Todo; discuss the immediate extension to your product (pick a high-priority item, some functionality that would be essential for users of your site).

### Learning experience

**Content learning reflection.** In general, this course can be described as a course on fundamentals of software engineering, agile product development, and web programming. Discuss your take-home ideas in each of these three categories (at least one per category). You can discuss what you have learned or what you’re going to use in your future projects (mention specific examples and reasons). 

**Process learning reflection.** There was some individual learning involved, there’s something you learned by working in pairs and groups, and by being in this class. Discuss your take-home ideas in each of these three categories (at least one per category).  You can discuss what you have learned about yourself as a developer, about working with AI, and tips/good practices for using it efficiently. 

There are at least 6 items to address in total. Each team should prepare a joint answer to all six of them. 

**Timing:** plan for your presentation to have 3 parts (product demo with a problem discussion (2) and extension discussion (3), content learning reflection, process learning reflection). Your presentation should aim to be around 15 minutes with roughly equal time allocated to 3 parts. Practice the presentation in advance to see where you stand w.r.t. Time. 

Due to the large number of teams, the time allocated for 1 presentation will be 10 minutes. You will receive a randomly assigned card stating which parts of the presentation you will run. For instance, one card may read “product demo with a problem discussion, and process learning reflection) and these are parts that you will present in class. Please respect the time limit, presentations going over time will be interrupted. 

**Order:** Another modification we’ll do due to the large number of teams is splitting in sections.   
Section 1 will present between 12pm and 1pm, Section 2 between 1pm and 2pm. You are only required to attend and attentively participate in the presentations of your section. You are certainly welcome to stay for the entire duration of the final exam.   
There will be a small break around 1-1:05 pm. Section 1, please don’t leave before the break, and Section 2, don’t enter the room before the break unless you are there at the start.   
Section 1 (and order): Activity Finder, Climbing Competition, Closet Organizer, Landscape Guessr, Next Step Assistant, No Crumbs  
Section 2 (and order): NU sublets, NU things, Smart Shopping List, Stay in Touch Helper, Study Assistant 

   
**Other details.**   
The presentation should model a project presentation within medium-size software company:

* The presentation should move at a good pace with no filler content.    
* Posture and gestures should be relaxed and communicate confidence; manner of speech should be assertive, confident, enthusiastic.   
* Each present team member  should speak clearly and present a portion of group work (the division of presentation time does not have to be even).    
* Everyone should have an equally clear understanding of all parts of the presentation and everyone should be prepared to answer students’ and the instructor’s questions.

Dress like your favorite CS person, or professionally.  

You don’t need to prepare the slides. You can have notes and peek at them, but don’t plan to read from them. 

The grade for presentation will be composed from the score for carefully describing project work, the score for reflective analysis of learning experience, and the presentation mechanics (articulate delivery, professional behavior, staying within time bound, having all present team members talk, active engaged participation as audience,  etc). 