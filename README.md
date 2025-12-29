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
    echo 'TOKEN="your_bot_token"' >> /etc/environment
    echo 'CHAT_ID="your_chat_id"' >> /etc/environment
    ```
2.  **Notification Script** (`/usr/local/bin/ssh_tg_notify.sh`):
    The script checks `PAM_TYPE` to avoid sending alerts during logout.
    ```bash
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
2.  **Create the Vagrantfile**:
    Save the following code as `Vagrantfile`. **Make sure to replace the TOKEN and CHAT_ID placeholders.**
    ```ruby
    Vagrant.configure("2") do |config|
      config.vm.box = "ubuntu/jammy64"
      
      config.vm.provision "shell", inline: <<-SHELL
        # Replace with your real credentials
        echo 'TOKEN="12345678:ABCDEF-Example"' >> /etc/environment
        echo 'CHAT_ID="987654321"' >> /etc/environment
        source /etc/environment

        # Install dependencies
        apt-get update && apt-get install -y fail2ban curl

        # Create the notification script
        cat <<EOF > /usr/local/bin/ssh_tg_notify.sh
        #!/bin/bash
        if [ "\\$PAM_TYPE" != "close_session" ]; then
            HOST=\\$(hostname)
            MSG="*Vagrant SSH Alert*%0A*Server:* \\$HOST%0A*User:* \\$PAM_USER%0A*IP:* \\$PAM_RHOST"
            curl -s -X POST "https://api.telegram.org/bot\\$TOKEN/sendMessage" \\
                -d "chat_id=\\$CHAT_ID" -d "text=\\$MSG" -d "parse_mode=Markdown"
        fi
        EOF
                chmod +x /usr/local/bin/ssh_tg_notify.sh

        # Enable PAM hook
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
