import std.stdio;
import std.getopt;
import std.file: exists, mkdir, isDir, readText, writeText = write;
import std.array: split, replace, popFront, join;
import std.algorithm.mutation: remove;
import std.algorithm.searching: canFind, count;
import std.process: wait, spawnProcess, ProcessConfig = Config;
import std.datetime: Clock, SysTime;
import std.format: format;
import std.path: dirSeparator;
import std.conv: to;

import std.net.curl;
import std.json;

import core.stdc.stdlib: exit;

import sily.curl;
import sily.getopt;
import std.path : absolutePath, buildNormalizedPath, expandTilde;
import sily.path: fixPath;

auto errorFunc = delegate void(HTTPStatusException e) {
    printError(e);
};

int main(string[] args) {
    bool doList = false;
    bool listClosed = false;
    bool listAll = false;
    bool verbose = false;
    bool add = false;
    string title = "";
    string description = "";
    int edit = -1;
    int show = -1;
    int complete = -1;
    int uncomplete = -1;
    string setRepo = "";

    GetoptResult help = getopt(
        args,
        config.bundling,
        config.caseSensitive,
        config.passThrough,
        "list|l", "Lists active todo", &doList,
        "closed|c", "Lists only closed todo when used with --list", &listClosed,
        "all|a", "Lists all todo when used with --list", &listAll,
        "show|s", "Shows issue, use as '--show ID'", &show,
        "add|A", "Adds new todo", &add,
        "edit|E", "Edit todo, use as '--edit ID'", &edit,
        "complete|C", "Complete todo, use as '--complete ID'", &complete,
        "uncomplete|U", "Reopens todo, use as '--uncomplete ID'", &uncomplete,
        "title|t", "Sets title", &title,
        "description|d",
            "Can be used with --add and --edit to set description",
            &description,
        "repo|r", "Sets todo repository in 'OWNER/REPO' format. Required only once", &setRepo,
        "verbose|v", "For debug purposes, prints verbose curs requests", &verbose
    );

    if (help.helpWanted) {
        printGetopt("Usage: todoer [args]", "Options", help.options);
        return 0;
    }

    args.popFront();

    checkPath();

    if (setRepo != "") {
        writeText(repoPath.fixPath, setRepo);
    }

    string repo = readText(repoPath.fixPath).replace("\n", "");
    if (repo.length == 0) {
        writeln("Error: please set todo repository with '--repo' flag.");
        return 1;
    } else {
        if (repo.split("/").length != 2) {
            writeln("Error: please set todo repository as 'OWNER/REPO'.");
            return 1;
        }
    }

    string token = readText(tokenPath.fixPath).replace("\n", "");

    string[string] head = [
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " ~ token,
        "X-GitHub-Api-Version": "2022-11-28"
    ];

    FetchConfig conf = {
        headers: head,
        method: GET
    };

    JSONValue j;

    auto thenFunc = delegate void(string data) {
        j = parseJSON(data);
    };

    if (doList) {
        string query = "";
        if (listClosed) query ~= "state=closed";
        if (listAll) query ~= "state=all";

        fetch("https://api.github.com/repos/" ~ repo ~ "/issues?" ~ query, conf).then(thenFunc).except(errorFunc);

        if (j.array.length == 0) {
            if (listClosed) {
                writeln("No completed tasks yet.");
            } else
            if (listAll) {
                writeln("No tasks found.");
            } else {
                writeln("No pending tasks.");
            }
        }
        ulong max = 0;
        foreach (issue; j.array) {
            ulong l = (issue["number"].integer.to!string).length;
            if (max < l) max = l;
        }
        max += 1;
        foreach (issue; j.array) {
            long idx = issue["number"].integer;
            ulong l = (idx.to!string).length;
            writef("%d.%*s", idx, max - l, " ");
            if ((listClosed || listAll) && issue["state"].str != "open") {
                write("[x] ");
            } else {
                write("[ ] ");
            }
            writeln(issue["title"].str);
        }
        return 0;
    }

    if (add) {
        if (title == "") {
            writeln("Cannot create empty task without a title.");
            return 1;
        }

        string bdy = "{\"title\": \"" ~ title ~ "\"";
        if (description.length) bdy ~= ",\"body\":\"" ~ description ~ "\"";
        bdy ~= "}";

        conf.method = POST;
        conf.data = bdy;
        fetch("https://api.github.com/repos/" ~ repo ~ "/issues", conf).then(thenFunc).except(errorFunc);

        writeln("Created task number " ~ j["number"].integer.to!string);
        return 0;
    }

    if (show != -1) {

        fetch("https://api.github.com/repos/" ~ repo ~ "/issues/" ~ show.to!string, conf)
            .then(thenFunc).except(errorFunc);

        JSONValue issue = j;

        long idx = issue["number"].integer;
        writef("%d. ", idx);
        if ((listClosed || listAll) && issue["state"].str != "open") {
            write("[x] ");
        } else {
            write("[ ] ");
        }
        writeln(issue["title"].str);
        if (!issue["body"].isNull) {
            // TODO: parse MD body with sily.markdown thingy I need to write
            writeln(issue["body"].str);
        }
        return 0;
    }

    if (edit != -1) {
        if (title == "") {
            writeln("Cannot set empty title to task.");
            return 1;
        }
        string bdy = "{\"title\": \"" ~ title ~ "\"";
        if (description.length) bdy ~= ",\"body\":\"" ~ description ~ "\"";
        bdy ~= "}";

        conf.method = PATCH;
        conf.data = bdy;

        fetch("https://api.github.com/repos/" ~ repo ~ "/issues/" ~ edit.to!string, conf)
            .then(thenFunc).except(errorFunc);

        writeln("Done");

        // JSONValue j = parseJSON(response);
        return 0;
    }


    if (complete != -1) {
        string bdy = "{\"state\":\"closed\",\"state_reason\":\"completed\"}";

        conf.method = PATCH;
        conf.data = bdy;

        fetch("https://api.github.com/repos/" ~ repo ~ "/issues/" ~ complete.to!string, conf)
            .then(thenFunc).except(errorFunc);


        writeln("Done");

        return 0;
    }

    if (uncomplete != -1) {
        string bdy = "{\"state\":\"open\",\"state_reason\":\"reopened\"}";

        conf.method = PATCH;
        conf.data = bdy;

        fetch("https://api.github.com/repos/" ~ repo ~ "/issues/" ~ uncomplete.to!string, conf)
            .then(thenFunc).except(errorFunc);

        writeln("Done");

        return 0;
    }


    return 0;
}

void printError(HTTPStatusException e) {
    writeln("Error ", e.status, ": ", getErrorMessage(e.status));
    exit(1);
}

string getErrorMessage(int status) {
    switch (status) {
        case 301: return "Moved permanently.";
        // case 301: return "Task was transferred to another repository."; break;
        case 304: return "Not modified.";
        case 403: return "Forbidden.";
        case 404: return "Resource not found.";
        // case 404: writeln("Task does not exist or user lacks read access."); break;
        case 410: return "Gone.";
        // case 410: writeln("Issues are disabled in repository."); break;
        // case 410: writeln("Task was permanently deleted."); break;
        case 422: return "Validation failed.";
        default: return "Unknown error code.";
    }
}

string tokenPath = "~/.ssh/git-todoer";
string repoPath = "~/.config/todoer/repo";
string repoPathOnly = "~/.config/todoer";

void checkPath() {
    if (!tokenPath.fixPath.exists()) {
        writeln("Error: please generate your github token. Refer to 'Generating token' section in readme.");
        exit(1);
    }
    if (!repoPathOnly.fixPath.exists()) {
        mkdir(repoPathOnly.fixPath);
    }
    if (!repoPath.fixPath.exists()) {
        File f = File(repoPath.fixPath, "w+");
        f.close();
    }
}


