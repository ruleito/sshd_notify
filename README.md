This documentation provides a complete overview of the **SSH-Notify** project, designed for Ops engineers to secure Linux servers and receive instant Telegram alerts upon SSH login.
[![Alt-текст](./image/Screenshot%202025-12-29%20at%2012.44.09.png)](example)
## SSH Security & Telegram Notification System
This project implements a multi-layered security approach: **Fail2Ban** for brute-force protection, **IP-restricted SSH keys**, and a **PAM-triggered** notification engine.

### Core Security Components
| Component | Function | Implementation |
| :--- | :--- | :--- |
| **Telegram Bot** | Instant Alerting | Bash script using `curl` to Telegram API  |
| **Fail2Ban** | Brute-force Prevention | Custom jail for `sshd` with 3-retry limit  |
| **PAM Exec** | Execution Trigger | `pam_exec.so` executes the script on login  |
| **Authorized Keys** | Access Control | `from="IP/MASK"` restriction per SSH key |

### System Configuration
1.  **Environment Secrets**: Store credentials in `/etc/environment` to make them available to the PAM session.
    ```bash
    echo 'TOKEN="your_bot_token"' >> /etc/sshd_notify
    echo 'CHAT_ID="your_chat_id"' >> /etc/sshd_notify
    ```
2. Configure fail2ban
    install Fail2Ban
    ```bash 
    apt install fail2ban
    ```
    next step: add conf
    ```bash
        vim /etc/fail2ban/jail.d/sshd.local
    ```

    and paste this config

    ```bash
        [sshd]
        enabled = true
        port    = ssh
        filter  = sshd
        maxretry = 3        ; ban 3 lose
        findtime = 10m      ; windows 
        bantime  = 1h       ; bantime 
        ignoreip = 127.0.0.1/8 ::1 192.168.0.0/16
    ```

    restart service

    ```bash 
    systemctl restart fail2ban.service
    ```

    check service
    
    ```bash 
    systemctl is-active fail2ban.service
    ```
3. SSH hardering

 **Disable password login and enable PAM**
```bash
    sed -i 's/^#\?\s*PasswordAuthentication\s\+.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?\s*PubkeyAuthentication\s\+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#\?\s*UsePAM\s\+.*/UsePAM yes/' /etc/ssh/sshd_config
    systemctl restart sshd
```
4.  PAM Activation 
    **add this string to end file** `/etc/pam.d/sshd` 
    ```bash
    session    optional     pam_exec.so /usr/local/bin/ssh_tg_notify.sh
    ```
3.  **Notification Script** (`/usr/local/bin/ssh_tg_notify.sh`):
    The script checks `PAM_TYPE` to avoid sending alerts during logout.
    ```bash
    [ -f /etc/sshd_notify] && . /etc/sshd_notify
    #!/bin/bash
    if [ "$PAM_TYPE" != "close_session" ]; then
        HOST=$(hostname)
        MSG="*SSH Alert*%0A*Server:* $HOST%0A*User:* $PAM_USER%0A*IP:* $PAM_RHOST%0A*Time:* $(date '+%Y-%m-%d %H:%M:%S')"
        curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
             -d "chat_id=$CHAT_ID" -d "text=$MSG" -d "parse_mode=Markdown" > /dev/null
    fi
    ```
3.  **SSH Restrictions**: Harden `/etc/ssh/sshd_config` by disabling passwords and enforcing `UsePAM yes`. Restrict keys in `~/.ssh/authorized_keys` using `from="your_network_ip/mask"`.

***

## Testing with Vagrant
Vagrant allows you to test the entire flow (Fail2Ban, PAM, and Telegram) in a safe, isolated virtual machine.

### Prerequisites
- [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) installed.
- A Telegram Bot token and your Chat ID.

### Deployment Steps
1.  **Create Project Folder**:
    ```bash
    mkdir ssh-notify-test && cd ssh-notify-test
    ```
2. **clone repo**
    ```bash 
    git@github.com:ruleito/sshd_notify.git 
    ```
3.  **Create the Vagrantfile**:
    Save the following code as `Vagrantfile`. **Make sure to replace the TOKEN and CHAT_ID placeholders.**
    ```ruby
    Vagrant.configure("2") do |config|
        config.vm.box = "ubuntu/jammy64"
        config.vm.hostname = "sshd-notify-test"

        config.vm.provision "shell", inline: <<-SHELL
            set -e
            echo 'TOKEN="PUT_YOUR_BOT_TOKEN_HERE"' >> /etc/sshd_notify
            echo 'CHAT_ID="PUT_YOUR_CHAT_ID_HERE"' >> /etc/sshd_notify
            chmod 600 /etc/sshd_notify && chown root:root /etc/sshd_notify
            apt-get update
            apt-get install -y curl
            cat << 'EOF' > /usr/local/bin/ssh_tg_notify.sh
        #!/bin/bash
        [ -f /etc/sshd_notify ] && . /etc/sshd_notify
        if [ "$PAM_TYPE" != "close_session" ]; then
            HOST=$(hostname)
            MSG="*Vagrant SSH Alert*%0A*Server:* $HOST%0A*User:* $PAM_USER%0A*IP:* $PAM_RHOST"
            curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
                -d "chat_id=$CHAT_ID" \
                -d "text=$MSG" \
                -d "parse_mode=Markdown"
        fi
        EOF
            chmod +x /usr/local/bin/ssh_tg_notify.sh
            echo "session optional pam_exec.so /usr/local/bin/ssh_tg_notify.sh" >> /etc/pam.d/sshd
            systemctl restart ssh
        SHELL
        end
    ```
3.  **Launch and Test**:
    ```bash
    vagrant up
    # connect to our host
    vagrant ssh
    ```
4.  **Verification**:
    Check your Telegram. You should receive a message with the server hostname and your login details. If it fails, inspect the logs: `journalctl -u ssh` or check the environment: `cat /etc/environment`.

## NOTICE: 
you can use any messanger for send message, need read api and cook query 

example: 
yandex: https://yandex.ru/dev/messenger/doc/ru/api-requests/message-send-text

rocketchat: https://developer.rocket.chat/apidocs/send-message

slack: https://docs.slack.dev/reference/methods/chat.postMessage/
