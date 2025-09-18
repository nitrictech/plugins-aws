'use strict';

const crypto = require('crypto');

exports.handler = async (event) => {
    const request = event.Records[0].cf.request;
    
    // Preserve auth header for lambdas and other OAC dependent services
    // This functionality is moved from the CloudFront function
    if (request.headers['authorization']) {
        request.headers['x-forwarded-auth'] = [{
            key: 'X-Forwarded-Auth',
            value: request.headers['authorization'][0].value
        }];
    }
    
    // Only process webhook signing for POST/PUT/PATCH requests with body
    const method = request.method;
    if (!['POST', 'PUT', 'PATCH'].includes(method)) {
        return request;
    }

    // Check if x-amz-content-sha256 header already exists
    if (request.headers['x-amz-content-sha256']) {
        return request;
    }
    
    // Check if this is targeting a Lambda function URL origin
    const origin = request.origin;
    if (!origin || !origin.custom || !origin.custom.domainName || 
        !origin.custom.domainName.includes('lambda-url')) {
        return request;
    }
    
    try {
        // Get the body if present
        const body = request.body && request.body.data ? request.body.data : '';
        
        // Calculate SHA256 hash of the body
        const hash = crypto.createHash('sha256');
        
        // Handle base64 encoded body
        if (request.body && request.body.encoding === 'base64') {
            const buffer = Buffer.from(body, 'base64');
            hash.update(buffer);
        } else {
            // Plain text body
            hash.update(body || '');
        }
        
        const sha256Hash = hash.digest('hex');
        
        // Add the x-amz-content-sha256 header for SigV4 signing
        request.headers['x-amz-content-sha256'] = [{
            key: 'X-Amz-Content-Sha256',
            value: sha256Hash
        }];
    } catch (error) {
        console.error('Error calculating SHA256:', error);
        // Return the request unchanged if there's an error
        return request;
    }
    
    return request;
};