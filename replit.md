# Workflow Automation Platform - Ruby on Rails API

## Overview

This is a Ruby on Rails application that serves as a backend for a workflow automation platform. The system integrates with over 1000 external applications through webhooks and APIs, allowing users to create automated workflows (called "Konnects"). The application provides API endpoints for a React frontend and manages external service integrations through dedicated service classes.

## System Architecture

### Backend Architecture
- **Framework**: Ruby on Rails (API-only mode)
- **Architecture Pattern**: Service-oriented architecture with dedicated service classes for each external app
- **API Design**: RESTful API endpoints serving a React frontend
- **Authentication**: API key-based authentication (user authentication removed for external triggers)

### Key Design Decisions
- **Service Layer**: Each external application integration is isolated in its own service file (`app/models/service/{app_name}.rb`)
- **Webhook Management**: Centralized webhook handling through the Konnects controller
- **Workflow Execution**: Konnects model manages workflow creation and execution
- **External App Management**: App and AppEvent models handle metadata for integrated applications

## Key Components

### Controllers
- **KonnectsController**: Primary controller managing webhooks, workflow execution, and testing
  - Handles incoming webhooks from external applications
  - Executes created workflows (konnects)
  - Provides testing endpoints for workflow validation
- **Public API Controller**: Handles unauthenticated endpoints for app discovery

### Models
- **Konnect**: Core workflow model managing automation logic
- **App**: Represents external application integrations
- **AppEvent**: Manages action names and API endpoints for each app
- **User**: User management (authentication bypassed for external triggers)

### Service Layer
- **External App Services**: Located in `app/models/service/`
  - Each file handles specific third-party app integration (e.g., `rebrandly.rb`)
  - Contains API methods and business logic for external app interactions
  - Provides testing and execution methods for workflow actions

## Data Flow

1. **Webhook Reception**: External apps send webhooks to KonnectsController
2. **Workflow Trigger**: Webhooks trigger execution of associated konnects/workflows
3. **Service Execution**: Konnect model calls appropriate service methods for external app actions
4. **Response Handling**: Results are processed and returned to triggering application
5. **Testing Flow**: Dedicated test endpoints allow validation of integrations during workflow creation

## External Dependencies

### Integration Approach
- **1000+ External Apps**: Each integrated through dedicated service classes
- **Webhook Support**: Bidirectional communication with external applications
- **API Connections**: RESTful API calls to external services
- **Service Isolation**: Each external app maintains its own service file for maintainability

### Authentication Strategy
- **API Key Authentication**: Simplified authentication for external triggers
- **Public Endpoints**: Selected endpoints available without authentication
- **User Context**: Maintains user association for workflow ownership

## Deployment Strategy

### Current Setup
- **Rails API Backend**: Serves React frontend through API endpoints
- **Service Architecture**: Modular service files for easy maintenance and scaling
- **Webhook Infrastructure**: Handles high-volume webhook processing from multiple external sources

### Scalability Considerations
- **Service Isolation**: Individual service files allow for independent updates
- **Modular Design**: Easy addition of new external app integrations
- **API-First**: Clean separation between backend logic and frontend presentation

## Recent Changes

- July 04, 2025. Fixed JSON body parameter parsing for all POST endpoints
- July 04, 2025. Fixed service action execution flow in ExternalAppServiceExecutor
- July 04, 2025. Verified all API endpoints are working correctly with proper authentication
- July 04, 2025. Completed comprehensive testing of public and authenticated endpoints

## Changelog

- July 04, 2025. Initial setup with Rails framework transition to Sinatra due to Ruby compatibility issues
- July 04, 2025. Implemented complete API system with working authentication, service execution, and database integration

## User Preferences

Preferred communication style: Simple, everyday language.