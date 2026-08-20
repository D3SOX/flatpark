/*
 * Adds --no-sandbox to the JxBrowser Chromium process that renders the Schwab
 * OAuth login page.
 *
 * thinkorswim builds that login area with JxBrowser, which since 9.0 starts
 * Chromium with its own sandbox enabled. Chromium's namespace sandbox has to
 * create a new user namespace, and Flatpak's seccomp policy denies that inside
 * the sandbox (clone(CLONE_NEWUSER) and unshare() return EPERM), so the engine
 * exits with SANDBOX_NOT_SUPPORTED, OAuthLoginPanel fails to construct and the
 * login dialog comes up without a login form.
 *
 * The switch can only be passed on the Chromium command line: JxBrowser exposes
 * it as EngineOptions.disableSandbox() with no system property, and the Chromium
 * directory is set programmatically, so nothing in the launcher's vmoptions can
 * reach it. Rewriting the extracted binary is not an option either - JxBrowser
 * verifies the files in its bin directory on every start and re-extracts them
 * from chromium-linux64.7z when they differ.
 *
 * So intercept the exec instead. The JVM spawns the browser process through
 * jspawnhelper, which inherits LD_PRELOAD and finishes with execve(), and
 * Chromium passes the switch on to its own child processes from there.
 *
 * Only an executable named "chromium" below a .../jxbrowser/... directory is
 * touched, and only when the switch is not already present. Everything else,
 * including the app's own launcher and helpers, execs unchanged.
 */

#define _GNU_SOURCE

#include <dlfcn.h>
#include <stddef.h>
#include <string.h>
#include <unistd.h>

#define MAX_ARGS 512

typedef int (*execve_fn)(const char *, char *const[], char *const[]);
typedef int (*execv_fn)(const char *, char *const[]);

static execve_fn real_execve;
static execv_fn real_execv;
static execv_fn real_execvp;

/*
 * Resolve the real symbols when the library is loaded: dlsym() may allocate,
 * and these hooks run in freshly forked children where malloc is best avoided.
 */
__attribute__((constructor)) static void resolve_real_symbols(void)
{
    real_execve = (execve_fn)dlsym(RTLD_NEXT, "execve");
    real_execv = (execv_fn)dlsym(RTLD_NEXT, "execv");
    real_execvp = (execv_fn)dlsym(RTLD_NEXT, "execvp");
}

static int is_jxbrowser_chromium(const char *path)
{
    const char *base;

    if (path == NULL)
        return 0;

    base = strrchr(path, '/');
    base = (base != NULL) ? base + 1 : path;

    return strcmp(base, "chromium") == 0 && strstr(path, "/jxbrowser/") != NULL;
}

/*
 * Copy argv with --no-sandbox inserted right after argv[0]. The copy lives in
 * the caller's stack frame, so no allocation happens on the exec path. Returns
 * NULL when the switch is already there or argv is too long to copy, in which
 * case the caller execs the original argv.
 */
static char **argv_with_no_sandbox(char *const argv[], char *slots[MAX_ARGS])
{
    size_t count = 0;
    size_t i;

    if (argv == NULL || argv[0] == NULL)
        return NULL;

    while (argv[count] != NULL) {
        if (strcmp(argv[count], "--no-sandbox") == 0)
            return NULL;
        if (++count > MAX_ARGS - 2)
            return NULL;
    }

    slots[0] = argv[0];
    slots[1] = (char *)"--no-sandbox";
    for (i = 1; i < count; i++)
        slots[i + 1] = argv[i];
    slots[count + 1] = NULL;

    return slots;
}

int execve(const char *path, char *const argv[], char *const envp[])
{
    char *slots[MAX_ARGS];
    char **patched;

    if (is_jxbrowser_chromium(path)) {
        patched = argv_with_no_sandbox(argv, slots);
        if (patched != NULL)
            return real_execve(path, patched, envp);
    }

    return real_execve(path, argv, envp);
}

int execv(const char *path, char *const argv[])
{
    char *slots[MAX_ARGS];
    char **patched;

    if (is_jxbrowser_chromium(path)) {
        patched = argv_with_no_sandbox(argv, slots);
        if (patched != NULL)
            return real_execv(path, patched);
    }

    return real_execv(path, argv);
}

int execvp(const char *file, char *const argv[])
{
    char *slots[MAX_ARGS];
    char **patched;

    if (is_jxbrowser_chromium(file)) {
        patched = argv_with_no_sandbox(argv, slots);
        if (patched != NULL)
            return real_execvp(file, patched);
    }

    return real_execvp(file, argv);
}
