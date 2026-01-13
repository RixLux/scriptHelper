# Cleanup Text

---


# envclean

`envclean` is a small CLI utility to generate a safe `.env.example` file from an existing `.env` file by removing all values after `=`.

This helps prevent accidentally committing secrets while still documenting required environment variables.

---

## What it does

Input `.env`:  
DB_HOST=localhost  
DB_USER=admin  
DB_PASSWORD=supersecret

Output `.env.example`:  
DB_HOST=  
DB_USER=  
DB_PASSWORD=  

- Original `.env` is **not modified**
- Comments and structure are preserved
- Output is created in the same directory

---

## Setting it up as Global Command(optional)

### 1. Clone or copy the script

Place the script somewhere convenient, for example:

```

/home/Username/Tool/Script/scriptHelper/textCleanup/env-cleanup.sh

````

---

### 2. Move it into `~/.local/bin` and rename it

```bash
mkdir -p ~/.local/bin
mv env-cleanup.sh ~/.local/bin/envclean
```
> Note: you can use cp to replace mv and preserve the original script
---

### 3. Make it executable

```bash
chmod +x ~/.local/bin/envclean
```

---

### 4. Ensure `~/.local/bin` is in your PATH

Check:

```bash
echo $PATH
```

If `~/.local/bin` is missing, add this to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Reload your shell:

```bash
source ~/.bashrc   # or ~/.zshrc
```

---

## Usage

### Basic usage

```bash
envclean .env
```

### Drag & drop (terminal)

```bash
envclean [drag .env file here]
```

### No argument (auto-detect)

If a `.env` file exists in the current directory:

```bash
envclean
```

---

## Output

The cleaned file is written to:

```
.env.example
```

in the same directory as the input `.env`.

---

## Recommended `.gitignore`

```gitignore
.env
.env.*
!.env.example
```

This ensures secrets are never committed, while keeping a template for collaborators.

---

## Notes

* Existing `.env.example` will be overwritten
* Always review generated files before committing
* This tool is intended for development workflows

---

