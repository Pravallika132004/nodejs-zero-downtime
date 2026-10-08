# Node.js Zero-Downtime Deployment

## Project Overview

This project demonstrates zero-downtime deployment of a Node.js application using Docker, Docker Compose and Nginx.

## Architecture

Client
  |
  v
Nginx
  |
  +---- Node.js Instance 1
  |
  +---- Node.js Instance 2

During deployment:

Old Version
     |
     v
New Version Starts
     |
     v
Health Check
     |
     v
Nginx Traffic Switch
     |
     v
Old Version Removed

## Technologies

- Node.js
- Express.js
- Docker
- Docker Compose
- Nginx
- Jest
- Supertest

## Features

- Two Node.js application replicas
- Health checks
- Nginx reverse proxy
- Load balancing
- Graceful shutdown
- Blue-green deployment
- Zero-downtime traffic switching
- Container health validation
- Rollback support

## Run Locally

Install dependencies:

```bash
npm install