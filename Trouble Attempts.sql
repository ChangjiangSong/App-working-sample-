-- Query 1 Did the send invitation interaction occur on the first clientsession or afterwards?
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL),
FirstClientsession As
	(SELECT clientsessionid
from
	(select 
	userid,
	clientsessionid,
    t,
    rank()over(partition by userid order by t) rk
from
	(select 
	userid,
	clientsessionid,
	min(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) t
	from user_actions where userid in (select * from TroubleAttempts) 
	group by userid,clientSessionId) a) b
where rk = 1)
select count(distinct userid) count_SentInvitation from user_actions u right join FirstClientsession f on u.clientSessionId = f.clientSessionId 
where interaction = 'Send Invitation'; -- 10
-- 21% Multiple users Sent Invitation on the first clientsession  79% Multiple users Sent Invitation afterwards.

-- Query 2 What is the distribution of the number of log-ins for this group? (mainly 2 logins or more?)
WITH MultiLogin AS
-- select user id's of all users who have logged in more than once, and are not Hub App, regardless of version
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),

-- select all multi-users in this version
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),

-- select invitation senders who do not own events
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL)
select
	round(count(case when count_Login <2 then 1 else null end)/count(count_Login), 2) UsersLoginOnce,
    round(count(case when count_Login =2 then 1 else null end)/count(count_Login), 2) UsersLoginTwice,
    round(count(case when count_Login >2 then 1 else null end)/count(count_Login), 2) UsersLoginTwiceMore
from
(select
	userid,
    count(distinct clientSessionId) count_Login
from user_actions
where userid in (select * from TroubleAttempts)
and applicationVersion LIKE '2.7%'
Group by userId) TroubleAttempts;
/* Distribution of the number of log-ins for this group 2.7 version
UsersLoginOnce, UsersLoginTwice, UsersLoginTwiceMore
'0.17', '0.69', '0.14'
*/

-- Query 3 What is the average time between the log-ins?
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL),
TIme_Log_ins As
	(SELECT userid, Last_login, Next_Login,Login_diff_Mins,Login_diff_Hours
from
(select
	userid,
	Last_login,
    lead(Last_login)over(partition by userid order by Last_login) Next_Login,
    TIMESTAMPDIFF(MINUTE,Last_Login,lead(Last_login)over(partition by userid order by Last_login)) Login_diff_Mins,
    TIMESTAMPDIFF(hour,Last_Login,lead(Last_login)over(partition by userid order by Last_login)) Login_diff_Hours,
    count(userid)over(partition by userid order by userid) duplicate_users
from
	(select
		userid,
		clientSessionId,
		Max(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) Last_login
	from user_actions
	where userid in (select * from TroubleAttempts)
	and applicationVersion LIKE '2.7%'
	Group by userId,clientSessionId) time_diff) a
where duplicate_users = 1 or (Next_Login is not null and duplicate_users > 1))
select round(avg(Login_diff_Mins)/1440,2) avgdays_Login_time from TIme_Log_ins;
/* Multiple logins users who have trouble attempt login once per 141.1 mins (Outliers Removed), average_login time is 4.82 days with outliers 
The extreme value make huge bais to the Avg_Days, most of trouble attempt users login in multiple time in one day or even in one hour.*/

-- Query 4 What is the average time spent on the clientsession that includes ‘Send Invitation’?
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (0,1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL),
-- clientsessionid includes 'Send Invitation'
Uniquesessionid As
(SELECT distinct clientsessionid
from user_actions
where userid in (select * from TroubleAttempts)
and applicationVersion LIKE '2.7%' and interaction = 'Send Invitation')
select
	userid,
	TIMESTAMPDIFF(minute,first_time,last_time) Time_Spent
	-- round(avg(TIMESTAMPDIFF(minute,first_time,last_time)),0) Average_Time_Spent_Mins
from
(select 
	userid,
	u1.clientSessionId,
	Max(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) last_time,
	Min(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) first_time
from user_actions u1 join Uniquesessionid u2 on u1.clientsessionid = u2.clientsessionid
where userid NOT IN (0,1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
group by 1,2) a;
/* the average time spent on the clientsession that includes ‘Send Invitation is 6.55 mins without outliers.
when the outliers included, the outcome of average time spend on clientsession is 17 mins.
-- Subquery out of cte: Time spent for each clientsessionid that includes sendInvitation
 */

--  Query 5 What is the most common quit screen?
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL)
select 
	screenname,
    count(screenname)
from
	(select userid,screenname
from
	(select
	userid,clientsessionid,screenname, str_to_date(createdAt,'%Y-%m-%d %H:%i:%s') T,
    rank()over(partition by userId,clientsessionid order by str_to_date(createdAt,'%Y-%m-%d %H:%i:%s') desc) rk
	from user_actions where userid in (select * from TroubleAttempts) and applicationVersion LIKE '2.7%') a
where rk = 1
group by 1) a
group by 1
order by 2 desc;
/* The most common quit screen is New Invitation, then Feed
'Feed','8'
'Notification Details','2'
'New Invitation','18'
'My Invitations','3'
'Edit Profile','4'
'Contact Groups','1'
'Hub Points Stats','1'
'Settings','1'
*/

-- Query 6 What are the most common screen names that people visit?
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL),
ScreenName As
	(select userId,screenName,
	count(screenName)over(partition by userid, screenName order by screenName) cn
from user_actions where userid in (select * from TroubleAttempts) and applicationVersion LIKE '2.7%'),
-- Select the most common screen names that people visit
ScreenNameCounts AS
    (select distinct userid, screenName
from
(select 
	userid,
    screenName,
    cn,
	dense_rank()over(partition by userid order by cn desc) rk
from 
	ScreenName) a
where rk = 1)
select 
	screenName,
    cn
from
(select 
	distinct screenName,
    count(screenName)over(partition by screenName order by screenName) cn
 from ScreenNameCounts) a
order by cn desc;
-- The most common screen names that people visit is 'New Invitation'

-- Query 7 When were their last interactions? Can we expect them to come back again, or are they lost at this point?
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL)
select 
	userid,
    interaction,
	T
from
(select 
	userid,
    interaction,
    str_to_date(createdAt,'%Y-%m-%d %H:%i:%s') T,
    rank()over(partition by userid order by str_to_date(createdAt,'%Y-%m-%d %H:%i:%s') desc) rk
from user_actions where userid in (select * from TroubleAttempts) and user_actions.applicationVersion LIKE '2.7%' and interaction <> '' ) a
where rk = 1;
/* Month Distribution 
'2022-10-00','22'
'2022-11-00','12'
'2022-09-00','3'
*/

-- Query 8 What is the percentage of time users spend on new invitations screen
WITH MultiLogin AS
	(SELECT user_actions.userid AS userid
	FROM user_actions
	WHERE user_actions.userid NOT IN (0,1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
	GROUP BY user_actions.userid
	HAVING COUNT(DISTINCT user_actions.clientSessionId) > 1),
InvitationSenders AS
	(SELECT DISTINCT MultiLogin.userid
	FROM MultiLogin
	LEFT JOIN user_actions ON MultiLogin.userid = user_actions.userid
	WHERE user_actions.applicationVersion LIKE '2.7%'
	AND user_actions.screenName = 'New Invitation'
	AND user_actions.interaction = 'Send Invitation'),
TroubleAttempts As
	(SELECT DISTINCT InvitationSenders.userid
FROM InvitationSenders
LEFT JOIN an_events ON InvitationSenders.userID = an_events.ownerId
WHERE ownerId IS NULL),
-- clientsessionid includes 'Send Invitation'
Uniquesessionid As
	(SELECT distinct clientsessionid
from user_actions
where userid in (select * from TroubleAttempts)
and applicationVersion LIKE '2.7%' and interaction = 'Send Invitation'),
Time_spent_SI As(
select
	userid,
	TIMESTAMPDIFF(minute,first_time,last_time)Time_Spent
	-- round(avg(TIMESTAMPDIFF(minute,first_time,last_time)),0) Average_Time_Spent_Mins
from
(select 
	userid,
	u1.clientSessionId,
	Max(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) last_time,
	Min(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) first_time
from user_actions u1 join Uniquesessionid u2 on u1.clientsessionid = u2.clientsessionid
where userid NOT IN (0,1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 18, 19, 20, 22, 23, 28, 30, 31, 32, 33, 34, 35, 36, 37, 57, 3073, 196916, 208106, 217203)
group by 1,2) a),
Total_Time_spent_SI As(
select 
	userid, 
	sum(TIMESTAMPDIFF(minute,first_time,last_time)) Total_Time_Spent
from
(select 
	userid, 
    clientSessionid,
	Max(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) last_time,
	Min(str_to_date(createdAt,'%Y-%m-%d %H:%i:%s')) first_time
from user_actions 
where userid in (select * from TroubleAttempts)
group by userid, clientSessionid) a
group by 1)
select 
    round(avg(t1.time_spent/t2.Total_Time_Spent),2) avg_ratio
from Time_spent_SI t1 left join Total_Time_spent_SI t2 on t1.userid = t2.userid

-- Trouble Attempts spent 51% time on New invitation screen compare to the other screen they viewed.
/* Summary 
1. Definition: These users are the users who login multiple times and have at least one sent invitation action but actually have not sent any invitation at all. (Tech issue or other issue)
2. 21% Multiple users Sent Invitation on the first clientsession  79% Multiple users Sent Invitation afterwards.
3. 81% users in this segmentation login at least twice in version 2.7 and 91% of them login on Oct and Nov; The average time between the log-ins is 141.4mins
4. the average time spent on the clientsession that includses ‘Send Invitation is 6.55 mins 
5. Both the most common quit screen and the most common screen names that people visit is "New invitation"
 
I believe there are no sufficient information to prove these users will come back again, or they lost at this point.
However,I think they can be divided into the potential Power Users.
The first reason is that they are the multiple login users and they even login multiple times after 2.7.0 version updated, which they are active to getting know about the App.
Second second reason is that they spent their most time on view New Invitation screen and the last quit screename is also New Invitation. These can strongly show that they are pretty interested to the core function of the App
Last but not the least, these users did make the action on sending at least one invitation to experience the core function of the App.
Thus, they can be considered as the potential Power Users even if we are not sure these users certainly back to app again.
*/
