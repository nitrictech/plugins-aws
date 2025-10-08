'use strict';

exports.handler = async () => {
    return {
        statusCode: 404,
        headers: {
            'Content-Type': 'text/plain',
            'Cache-Control': 'no-cache, no-store, must-revalidate'
        },
        body: '404 - Not Found'
    };
};