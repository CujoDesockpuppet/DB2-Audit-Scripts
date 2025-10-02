This shell script, named logmove.sh, is designed to archive DB2 audit log files by moving them from a source directory to a destination directory. It includes robust features like user validation, a locking mechanism to prevent multiple instances from running, and detailed logging. The script is specifically written with portability in mind, aiming to be compatible with both Bash and older Korn Shell (ksh) environments, such as those found on AIX.

Core Functionality
The script's primary function is to move specific files from a source to a destination directory based on two criteria:

Age: Files must be older than 35 days.

Ownership: Files must be owned by the DB2 database user, which is automatically determined by the script.

It also generates a report of all files successfully moved or failed to move.

Key Features and Components
1. User and Environment Validation
The script ensures it's being run by the correct DB2 database user (e.g., db2<sid>). It does this by comparing the current user (whoami) to a user name it constructs from the DB2DBDFT environment variable. If there's a mismatch, it exits with an error.

2. Single-Instance Locking Mechanism
To prevent two copies of the script from running at the same time and causing conflicts, the script uses a locking mechanism. It attempts to create a temporary directory (/tmp/logarch_<sid>.lock). If the directory already exists (meaning another instance is running), the script exits with an error code of 99. The lock is automatically removed when the script finishes, whether it succeeds or fails, using a trap command.

3. Logging and Reporting
The script uses a temporary log file (/tmp/logmove_<pid>) to capture all its runtime messages. Upon completion, it moves this temporary file to a permanent location within the script's log directory, naming it with a timestamp for easy tracking. Additionally, it creates a separate, dedicated report file in the destination directory (moved_files_report_<date>.log) that specifically lists which files were moved.

4. Portability and Error Handling
Portability: The script avoids modern Bash-specific syntax (like ^^ for uppercase conversion), replacing them with the more widely supported tr command. This makes it more compatible with older Unix/Linux systems.

Error Handling: The script includes checks to ensure both the source and destination directories exist before attempting to move files. If a directory is missing, it exits with a specific error code (60 or 61) and logs the issue. It also handles file move failures and logs those as well.

Dependencies and Prerequisites
Environment Variable: The script relies on the DB2DBDFT environment variable being set to the DB2 instance SID.

DB2 User: It must be executed by the DB2 database user (e.g., db2<sid>).

File Permissions: The user running the script must have read and write permissions on the source directory and write permissions on the destination and log directories.
