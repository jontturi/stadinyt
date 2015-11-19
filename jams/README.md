# How to add a new event

To add a new even you can submit a pull request with the information of the jam
added to one of the `json` files in this directory. Once accepted
the page will be updated and your jam will be visible.

If you're not familiar with JSON then you can use this Google Form to submit a jam and an administrator will review your submission and create the change for you: <https://docs.google.com/forms/d/1L2tMc9mWZy62lNrXQsbhQmMF5pLKgfXZoDfF_z0ePKk/viewform>

Jams are organized by their starting year. Choose the `json` file that
corresponds to the year when your jam starts, if the file doesn't exist yet
then you can create it.

For example, let's create a new jam that starts *May 4th, 2014 at 12pm* and
lasts 10 days.

You'll need to create a new object in the `jams` array, the position doesn't
matter but for simplicity keep things in ascending order of start date.

If you are specifying a time in addition to the date for your start and end then
you should provide a timezone (otherwise it defaults to UTC). More information
on times and dates below.

The following fields are required: `name`,  `url`, `start_date`, `end_date`.

**jams/2014.json**

    {
      jams: [
        .. other jams ..,

        {
          "name": "My cool jam",
          "url": "http://example.com/my-jam",
          "start_date": "2014-05-04 13:00 -0700",
          "end_date": "2014-05-14 13:00 -0700"
        }
      ]
    }



Optionally you can provide the fields `description` and/or `image`.
Here's a more complete version of the above example:

**jams/2014.json**

    {
      jams: [
        .. other jams ..,

        {
          "name": "My cool jam",
          "url": "http://example.com/my-jam",
          "start_date": "2014-05-04 13:00 -0700",
          "end_date": "2014-05-14 13:00 -0700",
          "description": "This is the jam we've been waiting for, I hope you are ready. I know I am!"
        }
      ]
    }

### Date and time format

The following patterns are supported for parsing dates. If either the start or
end can't be parsed then the jam entry is invalid.

    YYYY-MM-DD HH:mm:ss Z
    YYYY-MM-DD HH:mm Z
    YYYY-MM-DD


`Z` means timezone, in the form `+0000`. So PST would be `-0700`. You must
provide 2 digits for day, month, or seconds even when they are less than 10. So
`05` for May, `01` for the first day of the month, etc.

The final format `YYYY-MM-DD` is special, there is no time or timezone. This
will cause the jam's start time to be `0:00` and end time to be `23:59` in the
viewer's local time zone on the respective days passed in. That makes an
inclusive range from start to end.

### Editing an existing jam

Feel free to edit any existing jams, and to fix any errors.