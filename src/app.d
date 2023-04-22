import std.stdio;
import std.getopt;
import std.file: exists, mkdir, isDir, readText, writeText = write;
import std.array: split, replace;
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


import sily.getopt;
import std.path : absolutePath, buildNormalizedPath, expandTilde;
// import sily.path: fixPath; // this version has kind of wrong expansion
string fixPath(string p) {
    return p.expandTilde.absolutePath.buildNormalizedPath;
}


int main(string[] args) {
    bool doList = false;
    bool listClosed = false;
    bool verbose = false;
    string add = "";
    string description = "";
    int edit = -1;
    int complete = -1;
    string setRepo = "";

    GetoptResult help = getopt(
        args,
        config.bundling,
        config.caseSensitive,
        config.passThrough,
        "list|l", "Lists all current todo", &doList,
        "closed", "Lists closed todo when used with --list", &listClosed,
        "add|a", "Adds new todo", &add,
        "description|d", "Can be used with --add and --edit to set description", &description,
        "edit|e", "Edit todo, use as '--edit ID'", &edit,
        "complete|c", "Complete todo, use as '--complete ID'", &complete,
        "repo|r", "Sets todo repository in 'OWNER/REPO' format. Required only once", &setRepo,
        "verbose|v", "For debug purposes, prints verbose curs requests", &verbose
    );

    if (help.helpWanted) {
        printGetopt("Usage: todoer [args]", "Options", help.options);
        return 0;
    }

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
    if (doList) {
        auto http = HTTP();
        http.addRequestHeader("Accept", "application/vnd.github+json");
        http.addRequestHeader("Authorisation", "Bearer " ~ token);
        http.addRequestHeader("X-Github-Api-Version", "2022-11-28");
        http.maxRedirects(uint.max);
        http.verbose(verbose);
        // TODO: try catch errors and print message
        auto response = get("https://api.github.com/repos/" ~ repo ~ "/issues", http);

        JSONValue j = parseJSON(response);
        // size_t issueCount = j.array.length;
        int i = 1;
        foreach (issue; j.array) {
            writeln("####### ISSUE " ~ i.to!string ~ " #######");
            writeln(issue["title"].str);
            if (!issue["body"].isNull) {
                writeln(issue["body"].str);
            }
            ++i;
        }
    }

    
    return 0;
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


