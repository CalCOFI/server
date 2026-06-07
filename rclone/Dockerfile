FROM rclone/rclone:latest

# Copy crontab and sync scripts
COPY ./crontab          /etc/crontabs/root
COPY ./backup.sh        /backup.sh
COPY ./gdrive_to_gcs.sh /gdrive_to_gcs.sh

# Make scripts executable
RUN chmod +x /backup.sh /gdrive_to_gcs.sh

# Keep container running with cron in debug mode
ENTRYPOINT []
CMD ["crond", "-f", "-d", "8"]
