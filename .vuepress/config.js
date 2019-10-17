module.exports = {
    title: 'Graph Demo',
    description: 'Graph Demo.',
    base: "/",
    dest: "priv/static",
    patterns: ['*.md'],
    markdown: {
        linkify: true
    },
    themeConfig: {
        displayAllHeaders: true,
        sidebar: [
            ['/', 'Overview'],
        ]
    }
};
