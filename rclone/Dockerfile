FROM rclone/rclone:latest

# Copy crontab and backup script
COPY ./crontab   /etc/crontabs/root
COPY ./backup.sh /backup.sh

# Make backup script executable
RUN chmod +x /backup.sh

# Keep container running with cron in debug mode
ENTRYPOINT []
CMD ["crond", "-f", "-d", "8"]
